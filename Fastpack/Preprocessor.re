module M = CCMap.Make(String);
module FS = FastpackUtil.FS;
module Process = FastpackUtil.Process;
module Ast = Flow_parser.Flow_ast;
module Loc = Flow_parser.Loc;

exception Error(string);

type output = {
  source: string,
  parsedSource: option(Ast.program(Loc.t, Loc.t)),
  warnings: list(string),
  dependencies: list(string),
  files: list(string),
};

module NodeService = {
  type t = {
    project_root: string,
    output_dir: string,
    nodeProcessPool: Lwt_pool.t(Process.t),
  };

  let make = (~project_root, ~output_dir, ~env, ()) => {
    project_root,
    output_dir,
    nodeProcessPool:
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
                  Re.exec_opt(Re.Posix.compile_pat("/|\\\\"), executable)
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
          let cmd = [|
            "node",
            List.fold_left(
              FilePath.concat,
              fpack_root,
              ["node-service", "index.js"],
            ),
            output_dir,
            project_root,
          |];

          Process.start(~env, cmd) |> Lwt.return;
        },
      ),
  };

  let process =
      (
        ~current_dir,
        ~loaders,
        ~filename,
        {project_root, nodeProcessPool, _},
        source,
      ) => {
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
      nodeProcessPool,
      process => {
        let%lwt () =
          Process.write(Yojson.to_string(message) ++ "\n", process);
        let%lwt line = Process.readLine(process);
        let sub = project_root ++ (Sys.win32 ? "\\" : "/");
        open Yojson.Safe.Util;
        let data = Yojson.Safe.from_string(line);
        let source = member("source", data) |> to_string_option;
        let strList = key =>
          member(key, data)
          |> to_list
          |> List.map(to_string_option)
          |> CCList.filter_map(item => item);
        let warnings =
          strList("warnings") |> List.map(CCString.replace(~sub, ~by="./"));
        let dependencies = strList("dependencies");
        let files = strList("files");

        switch (source) {
        | None =>
          let error =
            member("error", data)
            |> member("message")
            |> to_string
            |> CCString.replace(~sub, ~by="./");
          Lwt.fail(Error(error));
        | Some(source) =>
          /* Logs.debug(x => x("SOURCE: %s", source)); */
          Lwt.return({
            source,
            parsedSource: None,
            warnings,
            dependencies,
            files,
          })
        };
      },
    );
  };

  let finalize = ({nodeProcessPool, _}) => Lwt_pool.clear(nodeProcessPool);
};

type t = {
  nodeService: NodeService.t,
  envVar: M.t(string),
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
        let (source, parsedSource) =
          FastpackTranspiler.transpile_source(all_transpilers, source);
        /* Logs.debug(x => x("SOURCE: %s", ret)); */
        Lwt.return({
          source,
          parsedSource,
          warnings: [],
          dependencies: [],
          files: [],
        });
      }
    ) {
    | FastpackTranspiler.Error.TranspilerError(err) =>
      Lwt.fail(Error(FastpackTranspiler.Error.error_to_string(err)))
    | exn => Lwt.fail(exn)
    }
  };

let make = (~envVar, ~project_root, ~current_dir, ~output_dir, ()) =>
  Lwt.return({
    nodeService:
      NodeService.make(
        ~project_root,
        ~output_dir,
        ~env=M.bindings(envVar),
        (),
      ),
    envVar,
    project_root,
    current_dir,
    output_dir,
  });

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
    | Some(source) =>
      Lwt.return({
        source,
        parsedSource: None,
        warnings: [],
        dependencies: [],
        files: [],
      })
    }
  | Module.File({filename, preprocessors, _}) =>
    let rec make_chain = (preprocessors, chain) =>
      switch (preprocessors) {
      | [] => chain
      | _ =>
        let (loaders, rest) =
          preprocessors |> CCList.take_drop_while(p => p != "builtin");

        switch (loaders) {
        | [] => make_chain(List.tl(rest), [builtin, ...chain])
        | _ =>
          let {current_dir, nodeService, _} = preprocessor;
          make_chain(
            rest,
            [
              NodeService.process(
                ~current_dir,
                ~loaders,
                ~filename,
                nodeService,
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

    let%lwt (source, parsedSource, warnings, deps, files) =
      Lwt_list.fold_left_s(
        ((source, _, warnings, deps, files), process) => {
          let%lwt {
            source,
            parsedSource,
            warnings: more_warnings,
            dependencies: more_deps,
            files: more_files,
          } =
            process(source);
          Lwt.return((
            Some(source),
            parsedSource,
            warnings @ more_warnings,
            deps @ more_deps,
            files @ more_files,
          ));
        },
        (source, None, [], [], []),
        make_chain(preprocessors, []),
      );

    switch (source) {
    | None => Error.ie("Unexpected absence of source after processing")
    | Some(source) =>
      Lwt.return({source, parsedSource, warnings, dependencies: deps, files})
    };
  };

let finalize = ({nodeService, _}) => NodeService.finalize(nodeService);
