module M = Map.Make(String);
module FS = FastpackUtil.FS;

exception Error(string);

type processor =
  | Builtin
  | Node(string);

type config = {
  pattern_s: string,
  pattern: Re.re,
  processors: list(string),
};

type t = {
  get_processors: string => list(string),
  process:
    (Module.location, option(string)) =>
    Lwt.t((string, list(string), list(string))),
  configs: list(config),
  finalize: unit => unit,
};

let debug = Logs.debug;

let of_string = s => {
  let (pattern_s, processors) =
    switch (String.(s |> trim |> split_on_char(':'))) {
    | []
    | [""] => raise(Failure("Empty config"))
    | [pattern_s]
    | [pattern_s, ""] => (pattern_s, ["builtin"])
    | [pattern_s, ...rest] =>
      let processors =
        String.(rest |> concat(":") |> split_on_char('!'))
        |> List.filter_map(s => {
             let s = String.trim(s);
             s == "" ?
               None :
               (
                 switch (String.split_on_char('?', s)) {
                 | [] => raise(Failure("Empty processor"))
                 | [processor] => Some(processor)
                 | ["builtin", ""] => Some("builtin")
                 | [processor, opts] when processor != "builtin" =>
                   Some(processor ++ "?" ++ opts)
                 | _ => raise(Failure("Incorrect preprocessor config"))
                 }
               );
           });

      (pattern_s, processors);
    };

  let pattern =
    try (Re_posix.compile_pat(pattern_s)) {
    | Re_posix.Parse_error =>
      raise(Failure("Pattern regexp parse error. Use POSIX syntax"))
    };

  {pattern_s, pattern, processors};
};

let to_string = ({pattern_s, processors, _}) =>
  Printf.sprintf("%s:%s", pattern_s, String.concat("!", processors));

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
      Lwt.return((
        FastpackTranspiler.transpile_source(all_transpilers, source),
        [],
        [],
      ))
    ) {
    | FastpackTranspiler.Error.TranspilerError(err) =>
      Lwt.fail(Error(FastpackTranspiler.Error.error_to_string(err)))
    | exn => Lwt.fail(exn)
    }
  };

let empty = {
  get_processors: _ => [],
  process: (_, s) => Lwt.return((CCOpt.get_or(~default="", s), [], [])),
  configs: [],
  finalize: () => (),
};

let transpile_all = {
  get_processors: _ => ["builtin"],
  process: (_, s) => builtin(s),
  configs: [],
  finalize: () => (),
};

module NodeServer = {
  let processes = ref([]);
  let fp_in_ch = ref(Lwt_io.zero);
  let fp_out_ch = ref(Lwt_io.null);

  let start = (project_root, output_dir) => {
    module FS = FastpackUtil.FS;
    let fpack_binary_path =
      /* TODO: handle on Windows? */
      (
        switch (Sys.argv[0].[0]) {
        | '/'
        | '.' => Sys.argv[0]
        | _ => FileUtil.which(Sys.argv[0])
        }
      )
      |> FileUtil.readlink
      |> FS.abs_path(Unix.getcwd());

    let rec find_fpack_root = dir =>
      if (dir == "/") {
        Error.ie("Cannot find fastpack package directory");
      } else {
        if%lwt (Lwt_unix.file_exists @@ FilePath.concat(dir, "package.json")) {
          Lwt.return(dir);
        } else {
          find_fpack_root(FilePath.dirname(dir));
        };
      };

    let%lwt fpack_root =
      find_fpack_root @@ FilePath.dirname(fpack_binary_path);

    let cmd =
      Printf.sprintf(
        "node %s %s %s",
        List.fold_left(
          FilePath.concat,
          fpack_root,
          ["node-service", "index.js"],
        ),
        output_dir,
        project_root,
      );

    let%lwt (process, ch_in, ch_out) = FS.open_process(cmd);
    fp_in_ch := ch_in;
    fp_out_ch := ch_out;
    processes := [process];
    Lwt.return_unit;
  };

  let process =
      (~project_root, ~current_dir, ~output_dir, ~loaders, ~filename, source) => {
    let%lwt () =
      if (List.length(processes^) == 0) {
        start(project_root, output_dir);
      } else {
        Lwt.return_unit;
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

    let%lwt () = Lwt_io.write(fp_out_ch^, Yojson.to_string(message) ++ "\n");
    let%lwt line = Lwt_io.read_line(fp_in_ch^);
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
      let error = member("error", data) |> member("message") |> to_string;
      Lwt.fail(Error(error));
    | Some(source) =>
      debug(x => x("SOURCE: %s", source));
      Lwt.return((source, dependencies, files));
    };
  };

  let finalize = () =>
    List.iter(
      p => {
        p#terminate;
        p#close |> ignore;
      },
      processes^,
    );
};

let make = (~configs, ~project_root, ~current_dir, ~output_dir) => {
  let processors = ref(M.empty);

  let get_processors = filename =>
    switch (M.get(filename, processors^)) {
    | Some(processors) => processors
    | None =>
      let relname = FS.relative_path(current_dir, filename);
      let p =
        configs
        |> List.fold_left(
             (acc, {pattern, processors, _}) =>
               switch (acc) {
               | [] =>
                 switch (Re.exec_opt(pattern, relname)) {
                 | None => []
                 | Some(_) => processors
                 }
               | _ => acc
               },
             [],
           )
        |> List.rev;

      processors := M.add(filename, p, processors^);
      p;
    };

  let process = (location, source) =>
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
            )
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

  Lwt.return({
    get_processors,
    process,
    configs,
    finalize: NodeServer.finalize,
  });
};
