module M = Map.Make(String);
module FS = FastpackUtil.FS;
module Process = FastpackUtil.Process;

exception Error(string);

type t = {
  project_root: string,
  current_dir: string,
  output_dir: string,
};

let all_transpilers =
  FastpackTranspiler.[
    ReactJSX.transpile,
    StripFlow.transpile,
    Class.transpile,
    ObjectSpread.transpile,
  ];

let builtin = source =>
  switch (source) {
  | None => Lwt.fail(Error("Builtin transpiler always expects source"))
  | Some(source) =>
    try (
      {
        let ret = FastpackTranspiler.transpile_source(all_transpilers, source);
        /* Logs.debug(x => x("SOURCE: %s", ret)); */
        Lwt.return((ret, [], []));
      }
    ) {
    | FastpackTranspiler.Error.TranspilerError(err) =>
      Lwt.fail(Error(FastpackTranspiler.Error.error_to_string(err)))
    | exn => Lwt.fail(exn)
    }
  };

module NodeServer = {
  let node_project_root = ref("");
  let node_output_dir = ref("");

  let pool =
    Lwt_pool.create(
      1,
      ~dispose=Process.finalize,
      () => {
        let executable = Environment.getExecutable();
        let fpack_binary_path =
          /* TODO: handle on Windows? */
          (
            switch (executable.[0]) {
            | '/'
            | '.' => executable
            | _ =>
              switch (
                Re.exec_opt(Re_posix.compile_pat("/|\\\\"), executable)
              ) {
              | Some(_) => executable
              | None => FileUtil.which(Sys.argv[0])
              }
            }
          )
          |> FileUtil.readlink
          |> FS.abs_path(Unix.getcwd());

        let rec find_fpack_root = dir =>
          if (dir == "/") {
            Error.ie("Cannot find fastpack package directory");
          } else {
            if%lwt (Lwt_unix.file_exists @@
                    FilePath.concat(dir, "package.json")) {
              Lwt.return(dir);
            } else {
              find_fpack_root(FilePath.dirname(dir));
            };
          };

        let%lwt fpack_root =
          find_fpack_root @@ FilePath.dirname(fpack_binary_path);

        Logs.debug(x =>
          x("process created: %s %s ", fpack_binary_path, fpack_root)
        );
        let cmd =
          Printf.sprintf(
            "node %s %s %s",
            List.fold_left(
              FilePath.concat,
              fpack_root,
              ["node-service", "index.js"],
            ),
            node_output_dir^,
            node_project_root^,
          );

        Process.start(cmd) |> Lwt.return;
      },
    );

  let process =
      (~project_root, ~current_dir, ~output_dir, ~loaders, ~filename, source) => {
    if (node_project_root^ == "") {
      node_project_root := project_root;
      node_output_dir := output_dir;
    };

    /* Do not pass binary data through the channel */
    let source =
      switch (filename) {
      | None => source
      | Some(filename) =>
        if (FS.is_text_file(filename)) {
          source;
        } else {
          None;
        }
      };

    let to_json_string = s => `String(s);
    let message =
      `Assoc([
        ("rootContext", `String(current_dir)),
        ("loaders", `List(List.map(to_json_string, loaders))),
        ("filename", CCOpt.map_or(~default=`Null, to_json_string, filename)),
        ("source", CCOpt.map_or(~default=`Null, to_json_string, source)),
      ]);

    Lwt_pool.use(
      pool,
      process => {
        let%lwt () = Process.write(Yojson.to_string(message) ++ "\n", process);
        let%lwt line = Process.readLine(process);
        open Yojson.Safe.Util;
        let data = Yojson.Safe.from_string(line);
        let source = member("source", data) |> to_string_option;
        let dependencies =
          member("dependencies", data)
          |> to_list
          |> List.map(to_string_option)
          |> List.filter_map(item => item);

        let files =
          member("files", data)
          |> to_list
          |> List.map(to_string_option)
          |> List.filter_map(item => item);

        switch (source) {
        | None =>
          let error =
            member("error", data) |> member("message") |> to_string;
          Lwt.fail(Error(error));
        | Some(source) =>
          /* Logs.debug(x => x("SOURCE: %s", source)); */
          Lwt.return((source, dependencies, files))
        };
      },
    );
  };

  let finalize = () => Lwt_pool.clear(pool);
};

let make = (~project_root, ~current_dir, ~output_dir, ()) =>
  Lwt.return({project_root, current_dir, output_dir});

let run = (location, source, preprocessor: t) =>
  switch (location) {
  | Module.Main(_)
  | Module.EmptyModule
  | Module.Runtime =>
    switch (source) {
    | None =>
      Error.ie(
        "Unexpeceted absence of source for main / builtin / empty module",
      )
    | Some(source) => Lwt.return((source, [], []))
    }
  | Module.File({filename, preprocessors, _}) =>
    let rec make_chain = (preprocessors, chain) =>
      switch (preprocessors) {
      | [] => chain
      | _ =>
        let (loaders, rest) =
          preprocessors |> List.take_drop_while(p => p != "builtin");

        switch (loaders) {
        | [] => make_chain(List.tl(rest), [builtin, ...chain])
        | _ =>
          let {project_root, current_dir, output_dir} = preprocessor;
          make_chain(
            rest,
            [
              NodeServer.process(
                ~project_root,
                ~current_dir,
                ~output_dir,
                ~loaders,
                ~filename,
              ),
              ...chain,
            ],
          );
        };
      };

    let preprocessors =
      List.map(
        ((p, opt)) =>
          p
          ++ (
            if (opt != "") {
              "?" ++ opt;
            } else {
              "";
            }
          ),
        preprocessors,
      );

    let%lwt (source, deps, files) =
      Lwt_list.fold_left_s(
        ((source, deps, files), process) => {
          let%lwt (source, more_deps, more_files) = process(source);
          Lwt.return((Some(source), deps @ more_deps, files @ more_files));
        },
        (source, [], []),
        make_chain(preprocessors, []),
      );

    switch (source) {
    | None => Error.ie("Unexpected absence of source after processing")
    | Some(source) => Lwt.return((source, deps, files))
    };
  };

let finalize = _ => NodeServer.finalize();
