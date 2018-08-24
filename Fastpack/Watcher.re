open Lwt.Infix;
module FS = FastpackUtil.FS;
module M = Map.Make(String);
let debug = Logs.debug;

let collect_links = current_dir => {
  let node_modules = FilePath.concat(current_dir, "node_modules");
  let%lwt dirs =
    switch%lwt (FS.stat_option(node_modules)) {
    | Some({st_kind: Unix.S_DIR, _}) =>
      Lwt_unix.files_of_directory(node_modules) |> Lwt_stream.to_list
    | _ => Lwt.return([])
    };

  let%lwt links =
    Lwt_list.filter_map_s(
      dir => {
        let dir = FS.abs_path(node_modules, dir);
        try%lwt (
          {
            let%lwt link = Lwt_unix.readlink(dir);
            Lwt.return_some((dir, FS.abs_path(node_modules, link)));
          }
        ) {
        | Unix.Unix_error(Unix.EINVAL, _, _) => Lwt.return_none
        };
      },
      List.filter(d => d != "." && d != "..", dirs),
    );

  List.fold_left(
    (map, (link, path)) => M.add(path, link, map),
    M.empty,
    links,
  )
  |> Lwt.return;
};

let common_root = paths =>
  switch (paths) {
  | [] => failwith("Cannot operate on empty paths list")
  | [path] => path
  | _ =>
    let path_parts =
      paths
      |> List.map(String.split_on_char('/'))
      |> List.sort((p1, p2) => compare(List.length(p1), List.length(p2)));

    let pattern = List.hd(path_parts);
    let rest = List.tl(path_parts);
    let rec common_root' = (pattern, found, rest) =>
      switch (pattern) {
      | [] => found
      | [part, ..._] =>
        List.exists(parts => List.hd(parts) != part, rest) ?
          found :
          common_root'(
            List.tl(pattern),
            [part, ...found],
            List.(map(tl, rest)),
          )
      };

    common_root'(pattern, [], rest) |> List.rev |> String.concat("/");
  };

let start_watchman = root => {
  let subscription = Printf.sprintf("s-%f", Unix.gettimeofday());
  let subscribe_message =
    `List([
      `String("subscribe"),
      `String(root),
      `String(subscription),
      `Assoc([("fields", `List([`String("name")]))]),
    ])
    |> Yojson.to_string;

  let cmd = "watchman --no-save-state -j --no-pretty -p";
  let%lwt (started_process, ch_in, ch_out) = FS.open_process(cmd);
  /* TODO: validate if process is started at all */
  let%lwt () = Lwt_io.write(ch_out, subscribe_message ++ "\n");
  let%lwt _ = Lwt_io.read_line(ch_in);
  /* TODO: validate answer */
  /*{"version":"4.9.0","subscribe":"mysubscriptionname","clock":"c:1523968199:68646:1:95"}*/
  /* this line is ignored, receiving possible files */
  let%lwt _ = Lwt_io.read_line(ch_in);
  Lwt.return((started_process, ch_in));
};

let ask_watchman = ch =>
  switch%lwt (Lwt_io.read_line_opt(ch)) {
  | None => Lwt.return_none
  | Some(line) =>
    open Yojson.Safe.Util;
    let data = Yojson.Safe.from_string(line);
    let root = member("root", data) |> to_string;
    let files =
      member("files", data)
      |> to_list
      |> List.map(to_string)
      |> List.map(filename => FS.abs_path(root, filename));

    Lwt.return_some(files);
  };

let watch = (~run, ~ctx: Context.t) => {
  /* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
   * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
   * */
  let (w, u) = Lwt.wait();
  Lwt_unix.on_signal(Sys.sigint, _ => Lwt.wakeup_exn(u, Context.ExitOK))
  |> ignore;
  Lwt_unix.on_signal(Sys.sigterm, _ => Lwt.wakeup_exn(u, Context.ExitOK))
  |> ignore;

  let process = ref(None);
  let%lwt link_map = collect_links(ctx.current_dir);
  let link_paths =
    link_map
    |> M.bindings
    |> List.map(fst)
    |> List.sort((s1, s2) =>
         Pervasives.compare(String.length(s1), String.length(s2))
       )
    |> List.rev;

  let common_root = common_root([ctx.current_dir, ...link_paths]);
  let common_root =
    if (common_root != "") {
      common_root;
    } else {
      ctx.current_dir;
    };
  let%lwt (started_process, ch_in) = start_watchman(common_root);
  process := Some(started_process);
  let%lwt () =
    Lwt_io.(write(stdout, "Watching file changes (Ctrl+C to stop)\n"));

  let rec find_linked_path = filename =>
    fun
    | [] => filename
    | [path, ...paths] =>
      switch (FilePath.is_subdir(filename, path)) {
      | false => find_linked_path(filename, paths)
      | true =>
        let relative = FilePath.make_relative(path, filename);
        switch (M.get(path, link_map)) {
        | Some(base_path) => FS.abs_path(base_path, relative)
        | None => failwith("Path not found in the links map: " ++ path)
        };
      };

  let rec read_pack = graph =>
    switch%lwt (ask_watchman(ch_in)) {
    | None => Lwt.return_unit
    | Some(filenames) =>
      let start_time = Unix.gettimeofday();
      let filenames =
        List.map(
          filename => find_linked_path(filename, link_paths),
          filenames,
        );

      List.iter(ctx.cache.remove, filenames);
      let%lwt graph =
        switch (DependencyGraph.get_modules_by_filenames(graph, filenames)) {
        /* Something is changed in the dir, but we don't care */
        | [] => Lwt.return(graph)
        /* Exactly one module is changed */
        | [m] =>
          DependencyGraph.remove_module(graph, m);
          let%lwt result =
            run(
              ~current_location=Some(m.location),
              ~graph=Some(graph),
              ~initial=false,
              ~start_time,
            );

          switch (result) {
          | Ok(ctx) => Lwt.return(ctx.Context.graph)
          | Error(_) =>
            DependencyGraph.add_module(graph, m);
            Lwt.return(graph);
          };
        | _ =>
          let%lwt result =
            run(
              ~current_location=None,
              ~graph=None,
              ~initial=false,
              ~start_time,
            );

          switch (result) {
          | Ok(ctx) => Lwt.return(ctx.Context.graph)
          | Error(_) => Lwt.return(graph)
          };
        };

      ([@tailcall] read_pack)(graph);
    };

  let finalize = () => {
    let () =
      switch (process^) {
      | None => ()
      | Some(process) => process#terminate
      };

    Lwt.return_unit;
  };

  Lwt.finalize(() => read_pack(ctx.Context.graph) <?> w, finalize);
};
