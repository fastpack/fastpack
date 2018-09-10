open Lwt.Infix;
module FS = FastpackUtil.FS;
module Process = FastpackUtil.Process;
module M = Map.Make(String);
module StringSet = Set.Make(String);

type t = {
  watch: unit => Lwt.t(unit),
  finalize: unit => Lwt.t(unit),
};

let build = (packer: Packer.t) => {
  let%lwt initial_result =
    Packer.pack(
      ~current_location=None,
      ~graph=None,
      ~initial=true,
      ~start_time=Unix.gettimeofday(),
      packer,
    );

  switch (initial_result) {
  | Error((ctx: Context.t)) =>
    Lwt.return_error((ctx, DependencyGraph.get_files(ctx.graph)))
  | Ok((ctx: Context.t)) =>
    Lwt.return_ok((ctx, DependencyGraph.get_files(ctx.graph)))
  };
};

let rebuild = (~filesChanged: StringSet.t, ~packer, prev_result) => {
  let start_time = Unix.gettimeofday();
  let (result, ctx: Context.t, filesWatched: StringSet.t) =
    switch (prev_result) {
    | Error((ctx, filesWatched)) => (`Error, ctx, filesWatched)
    | Ok((ctx, filesWatched)) => (`Ok, ctx, filesWatched)
    };

  StringSet.iter(f => Cache.File.invalidate(f, ctx.cache), filesChanged);
  switch (StringSet.(inter(filesChanged, filesWatched) |> elements)) {
  | [] => Lwt.return(prev_result)
  | filesChanged =>
    let (runPack, graph, current_location) =
      switch (result) {
      | `Error => (true, None, None)
      | `Ok =>
        switch (
          DependencyGraph.get_changed_module_locations(
            ctx.graph,
            filesChanged,
          )
          |> Module.LocationSet.elements
        ) {
        | [] => (false, None, None)
        | [location] =>
          DependencyGraph.remove_module(ctx.graph, location);
          (true, Some(ctx.graph), Some(location));
        | _ => (true, None, None)
        }
      };
    let%lwt newResult =
      if (runPack) {
        Packer.pack(
          ~current_location,
          ~graph,
          ~initial=false,
          ~start_time,
          packer,
        );
      } else {
        switch (result) {
        | `Ok => Lwt.return_ok(ctx)
        | `Error => Lwt.return_error(ctx)
        };
      };
    switch (newResult) {
    | Ok(ctx) => Lwt.return_ok((ctx, DependencyGraph.get_files(ctx.graph)))
    | Error((ctx: Context.t)) =>
      Lwt.return_error((
        ctx,
        StringSet.union(DependencyGraph.get_files(ctx.graph), filesWatched),
      ))
    };
  };
};

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
  let process = Process.start(cmd);
  /* TODO: validate if process is started at all */
  let%lwt () = Process.write(subscribe_message ++ "\n", process);
  let%lwt _ = Process.readLine(process);
  /* TODO: validate answer */
  /*{"version":"4.9.0","subscribe":"mysubscriptionname","clock":"c:1523968199:68646:1:95"}*/
  /* this line is ignored, receiving possible files */
  let%lwt _ = Process.readLine(process);
  Lwt.return(process);
};

let rec find_linked_path = (filename, link_map) =>
  fun
  | [] => filename
  | [path, ...paths] =>
    switch (FilePath.is_subdir(filename, path)) {
    | false => find_linked_path(filename, link_map, paths)
    | true =>
      let relative = FilePath.make_relative(path, filename);
      switch (M.get(path, link_map)) {
      | Some(base_path) => FS.abs_path(base_path, relative)
      | None => failwith("Path not found in the links map: " ++ path)
      };
    };

let rec ask_watchman = (process, link_map, link_paths, ignoreFilename) => {
  let%lwt line = Process.readLine(process);
  open Yojson.Safe.Util;
  let data = Yojson.Safe.from_string(line);
  let root = member("root", data) |> to_string;
  let files =
    member("files", data)
    |> to_list
    |> List.map(to_string)
    |> List.map(filename => FS.abs_path(root, filename))
    |> List.map(filename => find_linked_path(filename, link_map, link_paths))
    |> List.filter(ignoreFilename)
    |> List.fold_left(
         (set, filename) => StringSet.add(filename, set),
         StringSet.empty,
       );
  if (files == StringSet.empty) {
    ask_watchman(process, link_map, link_paths, ignoreFilename);
  } else {
    Lwt.return_some(files);
  };
};

let make = (~packer=None, config: Config.t) => {
  let%lwt packer =
    switch (packer) {
    | Some(packer) => Lwt.return(packer)
    | None => Packer.make({...config, mode: Mode.Development})
    };

  let%lwt currentDir = Lwt_unix.getcwd();

  let process = ref(None);
  let%lwt link_map = collect_links(currentDir);
  let link_paths =
    link_map
    |> M.bindings
    |> List.map(fst)
    |> List.sort((s1, s2) =>
         Pervasives.compare(String.length(s1), String.length(s2))
       )
    |> List.rev;

  let%lwt prevResult = build(packer);
  let%lwt started_process = start_watchman(config.projectRootDir);
  process := Some(started_process);
  let%lwt () =
    Lwt_io.(
      write(
        stdout,
        Printf.sprintf("Watching directory: %s \n", config.projectRootDir),
      )
    );
  let%lwt () = Lwt_io.(write(stdout, "(Ctrl+C to stop)\n"));
  let ignoreFilename = filename =>
    !FilePath.is_subdir(filename, config.outputDir)
    && filename != config.outputDir;

  let rec tryRebuilding = (filenames, prevResult) => {
    let%lwt nextResult =
      Lwt.pick([
        switch%lwt (
          ask_watchman(started_process, link_map, link_paths, ignoreFilename)
        ) {
        | None => raise(Context.ExitError("No input from watchman"))
        | Some(filenames) => `FilesChanged(filenames) |> Lwt.return
        },
        {
          let%lwt result =
            rebuild(~filesChanged=filenames, ~packer, prevResult);
          `Rebuilt(result) |> Lwt.return;
        },
      ]);
    switch (nextResult) {
    | `FilesChanged(newFilenames) =>
      tryRebuilding(StringSet.union(filenames, newFilenames), prevResult)
    | `Rebuilt(result) => Lwt.return(result)
    };
  };

  let lastResult = ref(prevResult);
  let lastResultCachedDumped = ref(None);
  let dumpCache = () =>
    switch (lastResult^) {
    | Ok((ctx: Context.t, _)) =>
      let dump = (ctx: Context.t, result) => {
        let%lwt () = Cache.save(ctx.cache);
        lastResultCachedDumped := Some(result);
        Lwt.return_unit;
      };
      switch (lastResultCachedDumped^) {
      | None => dump(ctx, lastResult^)
      | Some(lastResultCachedDumped) =>
        if (lastResult^ !== lastResultCachedDumped) {
          dump(ctx, lastResult^);
        } else {
          Lwt.return_unit;
        }
      };
    | Error(_) => Lwt.return_unit
    };

  let rec watch = result =>
    switch%lwt (
      ask_watchman(started_process, link_map, link_paths, ignoreFilename)
    ) {
    | None => Lwt.return_unit
    | Some(filenames) =>
      let%lwt result = tryRebuilding(filenames, result);
      lastResult := result;
      watch(result);
    };

  /* Workaround, since Lwt.finalize doesn't handle the signal's exceptions
   * See: https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763
   * */
  let (w, u) = Lwt.wait();
  let exit = _ => Lwt.wakeup_exn(u, Context.ExitOK);
  Lwt_unix.on_signal(Sys.sigint, exit) |> ignore;
  Lwt_unix.on_signal(Sys.sigterm, exit) |> ignore;

  Lwt.return({
    watch: () => watch(prevResult) <&> FS.setInterval(5., dumpCache) <?> w,
    finalize: () => {
      let%lwt () = Packer.finalize(packer);
      switch (process^) {
      | None => Lwt.return_unit
      | Some(process) => Process.finalize(process)
      };
    },
  });
};
