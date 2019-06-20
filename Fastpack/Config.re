open Cmdliner;
module FS = FastpackUtil.FS;
module M = CCMap.Make(String);
module StringSet = Set.Make(String);

module StringParam = {
  let createElement = (~title, ~nl=false, ~children: list(string), ()) =>
    <Pastel>
      <Pastel bold=true> {title ++ ": "} </Pastel>
      <Pastel> {String.concat("", children)} </Pastel>
      {nl ? "\n" : ""}
    </Pastel>;
};

module MaybeStringParam = {
  let createElement = (~title, ~value, ~children, ()) =>
    switch (value) {
    | None => ""
    | Some(value) =>
      <StringParam title nl=true>
        value
        {String.concat("", children)}
      </StringParam>
    };
};

let raiseConfigError = (~file=?, ~location=?, msg) =>
  raise(
    Error.ExitError(
      Pastel.(
        <Pastel>
          <Pastel bold=true color=Red> "Conguration Error\n" </Pastel>
          <MaybeStringParam title="File" value=file />
          <MaybeStringParam title="Location" value=location />
          msg
        </Pastel>
      ),
    ),
  );

module Cache = {
  type t =
    | Use
    | Disable;
  let toString = cache =>
    switch (cache) {
    | Use => "use"
    | Disable => "disable"
    };
};

module Mock = {
  type t =
    | Empty
    | Mock(string);

  let toString = ((request, mock)) =>
    switch (mock) {
    | Empty => request
    | Mock(mock) => request ++ ":" ++ mock
    };

  let ofString = s =>
    switch (String.(s |> trim |> split_on_char(':'))) {
    | []
    | [""] => raise(Failure("Empty config"))
    | [request]
    | [request, ""] => (request, Empty)
    | [request, ...rest] =>
      let mock = String.concat(":", rest);
      (request, Mock(mock));
    };

  let parse = s =>
    switch (ofString(s)) {
    | ok => Result.Ok((false, ok))
    | exception (Failure(msg)) => Result.Error(`Msg(msg))
    };

  let print = (ppf, (_, mock)) =>
    Format.fprintf(ppf, "%s", toString(mock));
};

module Preprocessor = {
  type t = {
    pattern_s: string,
    pattern: Re.re,
    processors: list(string),
  };

  let make = (~pattern_s, ~pattern, ~processors, ()) => {
    pattern_s,
    pattern,
    processors,
  };

  let defaultPattern = ".+";

  let isCatchAll = ({pattern_s, _}) => pattern_s == defaultPattern;

  let reOfString = s =>
    switch (Re.Posix.compile_pat(s)) {
    | compiled => compiled
    | exception Re.Posix.Parse_error =>
      raise(Failure("Invalid regexp. Use POSIX syntax"))
    };

  let preprocessorOfString = s =>
    switch (s) {
    | "" => "builtin"
    | _ =>
      switch (String.split_on_char('?', s)) {
      | [] => raise(Failure("Empty preprocessor"))
      | [preprocessor] => preprocessor
      | ["builtin", ""] => "builtin"
      | ["builtin", ..._] =>
        raise(Failure("Unexpected options for 'builtin' preprocessor"))
      | [preprocessor, ...opts] =>
        preprocessor ++ "?" ++ String.concat("?", opts)
      }
    };

  let preprocessorsOfString = s =>
    switch (String.split_on_char('!', s)) {
    | [] => raise(Failure("Empty config"))
    | ps => List.map(preprocessorOfString, ps)
    };

  let checkList = (preprocessors: list(t)) => {
    let length = List.length(preprocessors);
    let defaultPatternPositions =
      preprocessors
      |> List.mapi((pos, p) => (pos, p))
      |> CCList.filter_map(((pos, p)) =>
           p.pattern_s == defaultPattern ? Some(pos) : None
         );
    switch (defaultPatternPositions) {
    | [] => preprocessors
    | [pos] when pos == length - 1 => preprocessors
    | [pos, ..._] =>
      raise(
        Failure(
          Printf.sprintf(
            "The default preprocessor appears too early at position %d. There are %d more preprocessors which will never be executed.",
            pos,
            length - 1 - pos,
          ),
        ),
      )
    };
  };

  let ofString = s => {
    let (pattern_s, preprocessors) =
      switch (String.(s |> trim |> split_on_char(':'))) {
      | []
      | [""] => raise(Failure("Empty config"))
      | [pattern_s]
      | [pattern_s, ""] => (pattern_s, "")
      | [pattern_s, ...rest] => (pattern_s, String.concat(":", rest))
      };
    let pattern_s = pattern_s == "" ? defaultPattern : pattern_s;
    make(
      ~pattern_s,
      ~pattern=reOfString(pattern_s),
      ~processors=preprocessorsOfString(preprocessors),
      (),
    );
  };

  let toString = ({pattern_s, processors, _}) =>
    Printf.sprintf("%s:%s", pattern_s, String.concat("!", processors));

  let parse = s =>
    try (Result.Ok((false, ofString(s)))) {
    | Failure(msg) => Result.Error(`Msg(msg))
    };

  let print = (ppf, (_, opt)) => Format.fprintf(ppf, "%s", toString(opt));
};

module EnvVar = {
  type t = {
    name: string,
    default: string,
  };

  let ofString = s =>
    switch (String.(s |> trim |> split_on_char('='))) {
    | [] => raise(Failure("Empty value"))
    | [name] => {name, default: ""}
    | [name, default] => {name, default}
    | [name, ...rest] => {name, default: String.concat("=", rest)}
    };

  let toString = ({name, default}) => name ++ "=" ++ default;

  let parse = s =>
    try (Result.Ok((false, ofString(s)))) {
    | Failure(msg) => Result.Error(`Msg(msg))
    };

  let print = (ppf, (_, opt)) => Format.fprintf(ppf, "%s", toString(opt));
};

module File = {
  open Yojson.Safe;
  open Run.Syntax;

  type t = {
    config: M.t(json),
    source,
  }
  and source =
    | File(string)
    | Empty;

  let handleExc = f =>
    switch (f()) {
    | result => result
    | exception (Util.Type_error(msg, _)) => error(msg)
    | exception (Failure(msg)) => error(msg)
    };

  let failOnError = (f, file) =>
    switch (f(file)) {
    | Ok(result) => result
    | Error((msg, location)) =>
      let location =
        switch (location) {
        | [] => "(root)"
        | _ => String.concat(".", List.rev(location))
        };
      let filename =
        switch (file.source) {
        | Empty => "(no file)"
        | File(filename) => filename
        };
      raiseConfigError(~file=filename, ~location, msg ++ "\n");
    };

  let knownKeys = ref(StringSet.empty);

  let checkKeys = ({config, _} as file) => {
    let keys =
      config
      |> M.bindings
      |> List.fold_left(
           (set, (key, _)) =>
             switch (key.[0]) {
             | '_' => set /* we purposely ignore keys starting from '_' */
             | _ => StringSet.add(key, set)
             },
           StringSet.empty,
         );
    switch (StringSet.(diff(keys, knownKeys^) |> elements)) {
    | [] => return(file)
    | unknown =>
      error(
        Printf.sprintf(
          "Unexpected parameters in the config file: %s.\nUse one of the following: %s.",
          String.concat(", ", unknown),
          knownKeys^ |> StringSet.elements |> String.concat(", "),
        ),
      )
    };
  };

  let empty = () => {config: M.empty, source: Empty};

  let fromFile = (~fname, data) =>
    failOnError(
      ({source, _}) =>
        switch (from_string(~fname, data)) {
        | json =>
          let%bind config =
            handleExc(() =>
              Util.to_assoc(json) |> M.add_list(M.empty) |> return
            );
          checkKeys({config, source});
        | exception (Yojson.Json_error(msg)) => error(msg)
        },
      {...empty(), source: File(fname)},
    );

  let value = (key, f) => {
    knownKeys := StringSet.add(key, knownKeys^);
    failOnError(({config, _}) =>
      switch (M.get(key, config)) {
      | None => return(None)
      | Some(value) =>
        switch (Run.withContext(key, handleExc(() => f(value)))) {
        | Ok(value) => Ok(Some(value))
        | Error(e) => Error(e)
        }
      }
    );
  };

  let list = (key, f) => {
    knownKeys := StringSet.add(key, knownKeys^);
    failOnError(({config, _}) =>
      switch (M.get(key, config)) {
      | None => return([])
      | Some(value) =>
        Run.withContext(
          key,
          {
            let%bind list = handleExc(() => Util.to_list(value) |> return);
            let rec loop = (i, list) =>
              switch (list) {
              | [] => return([])
              | [hd, ...tl] =>
                let%bind hd =
                  Run.withContext(string_of_int(i), handleExc(() => f(hd)));
                let%bind tl = loop(i + 1, tl);
                return([hd, ...tl]);
              };
            loop(0, list);
          },
        )
      }
    );
  };

  let string = json => Util.to_string(json) |> return;
  let bool = json => Util.to_bool(json) |> return;

  let cache =
    value("cache", json =>
      return(Util.to_bool(json) ? Cache.Use : Cache.Disable)
    );

  let entryPoints = list("entryPoints", string);

  let mock =
    list("mocks", json => json |> Util.to_string |> Mock.ofString |> return);

  let mode =
    value("development", json =>
      return(Util.to_bool(json) ? Mode.Development : Mode.Production)
    );

  let nodeModulesPaths = list("nodeModulesPaths", string);

  let outputDir = value("outputDir", string);

  let outputFilename = value("outputFilename", string);

  let publicPath = value("publicPath", string);

  let preprocess =
    list("preprocess", json => {
      let obj = Util.to_assoc(json) |> M.add_list(M.empty);
      let%bind (pattern_s, pattern) =
        switch (M.get("re", obj)) {
        | None => raise(Failure("Missing expected \"re\" key"))
        | Some(value) =>
          Run.withContext(
            "re",
            {
              let pattern_s = Util.to_string(value);
              let pattern = Preprocessor.reOfString(pattern_s);
              return((pattern_s, pattern));
            },
          )
        };
      let%bind processors =
        switch (M.get("process", obj)) {
        | None => raise(Failure("Missing expected \"process\" key"))
        | Some(value) =>
          Run.withContext(
            "process",
            Util.to_string(value)
            |> Preprocessor.preprocessorsOfString
            |> return,
          )
        };
      Preprocessor.make(~pattern_s, ~pattern, ~processors, ()) |> return;
    });

  let envVar =
    value("envVars", json =>
      Util.to_assoc(json)
      |> List.map(((name, json)) =>
           {EnvVar.name, default: Util.to_string(json)}
         )
      |> return
    );

  let projectRootDir = value("projectRootDir", string);

  let resolveExtension = list("resolveExtensions", string);

  let packageMainFields = list("packageMainFields", string);

  let exportCheckUsedImportsOnly = value("exportCheckUsedImportsOnly", bool);
};

type t = {
  cache: value(Cache.t),
  entryPoints: value(list(string)),
  mock: list(value((string, Mock.t))),
  mode: value(Mode.t),
  nodeModulesPaths: list(value(string)),
  outputDir: value(string),
  outputFilename: value(string),
  publicPath: value(string),
  preprocess: list(value(Preprocessor.t)),
  envVar: M.t(value(string)),
  projectRootDir: value(string),
  resolveExtension: list(value(string)),
  packageMainFields: list(value(string)),
  exportCheckUsedImportsOnly: value(bool),
}
and value('a) = {
  source,
  value: 'a,
}
and source =
  | File
  | Arg
  | Default;

let create =
    (
      ~configFile,
      ~entryPoints,
      ~outputDir,
      ~outputFilename,
      ~publicPath,
      ~mode,
      ~mock,
      ~nodeModulesPaths,
      ~projectRootDir,
      ~resolveExtension,
      ~packageMainFields,
      ~cache,
      ~preprocess,
      ~envVar,
      ~exportCheckUsedImportsOnly,
    ) => {
  let readConfigFromFile = fname => {
    let%lwt content = Lwt_io.(with_file(~mode=Input, fname, read));
    Lwt.return(File.fromFile(~fname, content));
  };

  let%lwt configFile =
    switch (configFile) {
    | Some(filename) =>
      switch%lwt (Lwt_unix.file_exists(filename)) {
      | true => readConfigFromFile(filename)
      | false =>
        raiseConfigError(
          Printf.sprintf("Config file %s does not exist\n", filename),
        )
      }
    | None =>
      let filename = "./fastpack.json";
      switch%lwt (Lwt_unix.file_exists(filename)) {
      | true => readConfigFromFile(filename)
      | false => Lwt.return(File.empty())
      };
    };

  let pickValue = (~arg, ~file, ~default, ()) =>
    switch (arg, file) {
    | (Some(value), _) => {value, source: Arg}
    | (None, Some(value)) => {value, source: File}
    | _ => {value: default, source: Default}
    };

  let pickListValue = (~arg, ~file, ~default, ()) =>
    switch (arg, file) {
    | ([], []) => {value: default, source: Default}
    | ([], file) => {value: file, source: File}
    | _ => {value: arg, source: Arg}
    };

  let mergeLists = (~arg, ~file, ~default, ()) =>
    switch (arg, file) {
    | ([], []) => List.map(value => {value, source: Default}, default)
    | _ =>
      List.map(value => {value, source: Arg}, arg)
      @ List.map(value => {value, source: File}, file)
    };

  let entryPoints =
    pickListValue(
      ~arg=entryPoints,
      ~file=File.entryPoints(configFile),
      ~default=["."],
      (),
    );

  let outputDir =
    pickValue(
      ~arg=outputDir,
      ~file=File.outputDir(configFile),
      ~default="./bundle",
      (),
    );
  let outputFilename =
    pickValue(
      ~arg=outputFilename,
      ~file=File.outputFilename(configFile),
      ~default="index.js",
      (),
    );
  let publicPath =
    pickValue(
      ~arg=publicPath,
      ~file=File.publicPath(configFile),
      ~default="",
      (),
    );
  let mode =
    pickValue(
      ~arg=mode,
      ~file=File.mode(configFile),
      ~default=Mode.Production,
      (),
    );

  let mock =
    mergeLists(~arg=mock, ~file=File.mock(configFile), ~default=[], ());

  let nodeModulesPaths =
    mergeLists(
      ~arg=nodeModulesPaths,
      ~file=File.nodeModulesPaths(configFile),
      ~default=["node_modules"],
      (),
    );
  /* nodeModulesPaths == [] ? ["node_modules"] : nodeModulesPaths; */
  let projectRootDir =
    pickValue(
      ~arg=projectRootDir,
      ~file=File.projectRootDir(configFile),
      ~default=".",
      (),
    );

  let fixExt = exts =>
    exts
    |> List.filter(ext => String.trim(ext) != "")
    |> List.map(ext =>
         switch (ext.[0]) {
         | '.' => ext
         | _ => "." ++ ext
         }
       );

  let resolveExtension =
    mergeLists(
      ~arg=fixExt(resolveExtension),
      ~file=fixExt(File.resolveExtension(configFile)),
      ~default=[".js", ".json"],
      (),
    );

  let packageMainFields =
    mergeLists(
      ~arg=packageMainFields,
      ~file=File.packageMainFields(configFile),
      ~default=["browser", "module", "main"],
      (),
    );

  let preprocess =
    mergeLists(
      ~arg=preprocess,
      ~file=File.preprocess(configFile),
      ~default=[],
      (),
    );
  let _ =
    Preprocessor.checkList(List.map(({value, _}) => value, preprocess));

  let cache =
    pickValue(
      ~arg=cache,
      ~file=File.cache(configFile),
      ~default=Cache.Use,
      (),
    );

  let exportCheckUsedImportsOnly =
    pickValue(
      ~arg=exportCheckUsedImportsOnly,
      ~file=File.exportCheckUsedImportsOnly(configFile),
      ~default=false,
      (),
    );

  let currentDir = Unix.getcwd();

  /* output directory & output filename */
  let (outputDir, outputFilename) = {
    let outputDirValue = FS.abs_path(currentDir, outputDir.value);
    let outputFilenameValue =
      FS.abs_path(outputDirValue, outputFilename.value);
    let outputFilenameParent = FilePath.dirname(outputFilenameValue);
    if (outputDirValue == outputFilenameParent
        || FilePath.is_updir(outputDirValue, outputFilenameParent)) {
      (
        {...outputDir, value: outputDirValue},
        {...outputFilename, value: outputFilenameValue},
      );
    } else {
      raiseConfigError(
        <Pastel>
          "Output filename must be a subpath of the output directory.\n"
          <StringParam title="Output Directory" nl=true>
            outputDirValue
          </StringParam>
          <StringParam title="Output Filename" nl=true>
            outputFilenameValue
          </StringParam>
        </Pastel>,
      );
    };
  };
  let projectRootDir = {
    ...projectRootDir,
    value: FastpackUtil.FS.abs_path(currentDir, projectRootDir.value),
  };
  let getEnv = source =>
    List.map(({EnvVar.name, default}) =>
      switch (Unix.getenv(name)) {
      | value => (name, {value, source})
      | exception Not_found => (name, {value: default, source})
      }
    );
  let envVar =
    List.fold_left(
      (m, (name, value)) => M.add(name, value, m),
      M.empty,
      getEnv(File, File.envVar(configFile) |> CCOpt.get_or(~default=[]))
      @ getEnv(Arg, envVar)
      @ [
        (
          "NODE_ENV",
          {
            value:
              mode.value == Mode.Development ? "development" : "production",
            source: mode.source,
          },
        ),
      ],
    );
  Lwt.return({
    cache,
    entryPoints,
    mock,
    mode,
    nodeModulesPaths,
    outputDir,
    outputFilename,
    publicPath,
    preprocess,
    envVar,
    projectRootDir,
    resolveExtension,
    packageMainFields,
    exportCheckUsedImportsOnly,
  });
};

let term = {
  let run =
      (
        configFile,
        cache,
        entryPoints,
        mock,
        mode,
        nodeModulesPaths,
        outputDir,
        outputFilename,
        publicPath,
        preprocess,
        envVar,
        projectRootDir,
        resolveExtension,
        packageMainFields,
        exportCheckUsedImportsOnly,
      ) =>
    create(
      ~configFile,
      ~cache,
      ~entryPoints,
      ~mock=List.map(snd, mock),
      ~mode,
      ~nodeModulesPaths,
      ~outputDir,
      ~outputFilename,
      ~publicPath,
      ~preprocess=List.map(snd, preprocess),
      ~envVar=List.map(snd, envVar),
      ~projectRootDir,
      ~resolveExtension,
      ~packageMainFields,
      ~exportCheckUsedImportsOnly,
    );

  let configFileT = {
    let doc = "Config File";

    let docv = "CONFIG";
    Arg.(
      value
      & opt(~vopt=Some("./fastpack.json"), some(string), None)
      & info(["c", "config"], ~docv, ~doc)
    );
  };

  let entryPointsT = {
    let doc = "Entry points. Default: ['.']";

    let docv = "ENTRY POINTS";
    Arg.(value & pos_all(string, []) & info([], ~docv, ~doc));
  };

  let outputDirT = {
    let doc =
      "Output Directory. " ++ "The target bundle will be $(docv)/index.js.";

    let docv = "DIR";
    Arg.(
      value
      & opt(~vopt=Some("./bundle"), some(string), None)
      & info(["o", "output"], ~docv, ~doc)
    );
  };

  let outputFilenameT = {
    let doc =
      "Output File Name. " ++ "The target bundle filename will be $(docv)";

    let docv = "NAME";
    Arg.(
      value
      & opt(~vopt=Some("index.js"), some(string), None)
      & info(["n", "name"], ~docv, ~doc)
    );
  };

  let publicPathT = {
    let doc =
      "URL prefix to download the static assests and JavaScript chunks at runtime. "
      ++ "Points to the same location as --output-dir.";

    let docv = "URL";
    Arg.(
      value
      & opt(~vopt=Some(""), some(string), None)
      & info(["public-path"], ~docv, ~doc)
    );
  };

  let modeT = {
    open Mode;
    let doc = "Build bundle for development";
    let development = (Some(Development), Arg.info(["development"], ~doc));
    Arg.(value & vflag(None, [development]));
  };

  let nodeModulesPathsT = {
    let doc =
      "Paths to 'node_modules' directory. Should be inside the project directory."
      ++ ". Defaults to ['node_modules']";

    let docv = "PATH";
    Arg.(
      value
      & opt_all(string, [])
      & info(["nm", "node-modules"], ~docv, ~doc)
    );
  };

  let projectRootDirT = {
    let doc =
      "Ancestor to which node_modules will be resolved." ++ ". Defaults to '.'";

    let docv = "PATH";
    Arg.(
      value
      & opt(~vopt=Some("."), some(string), None)
      & info(["project-root"], ~docv, ~doc)
    );
  };

  let mockT = {
    let mock = Arg.conv(Mock.(parse, print));

    let doc =
      "Mock PACKAGE requests with SUBSTITUTE requests. If SUBSTITUTE is omitted"
      ++ " empty module is used.";

    let docv = "PACKAGE[:SUBSTITUTE]";
    Arg.(value & opt_all(mock, []) & info(["mock"], ~docv, ~doc));
  };

  let resolveExtensionT = {
    let doc =
      "Provide extensions to be considered by the resolver for the "
      ++ "extension-less path. Extensions will be tried in the specified order."
      ++ " If no extension should be tried, provide '' as an argument. Defaults "
      ++ "to [.js, .json]";

    let docv = "EXTENSION";
    Arg.(
      value & opt_all(string, []) & info(["resolve-extension"], ~docv, ~doc)
    );
  };

  let packageMainFieldsT = {
    let doc =
      "Field name in package.json to determine the package entry point. "
      ++ "Specify several in desired order. "
      ++ "Defaults to: [\"browser\", \"module\", \"main\"]";

    let docv = "PACKAGE-MAIN-FIELD";
    Arg.(
      value
      & opt_all(string, [])
      & info(["package-main-field"], ~docv, ~doc)
    );
  };

  let cacheT = {
    let doc = "Do not use cache at all (effective in development mode only)";

    let disable = (Some(Cache.Disable), Arg.info(["no-cache"], ~doc));
    Arg.(value & vflag(None, [disable]));
  };

  let preprocessT = {
    let preprocess = Arg.conv(Preprocessor.(parse, print));

    let doc =
      "Preprocess modules matching the PATTERN with the PROCESSOR. Optionally,"
      ++ " the processor may receive some OPTIONS in form: 'x=y&a=b'. There are"
      ++ " 2 kinds of currently supported processors: 'builtin' and the "
      ++ "Webpack loader. 'builtin' preprocessor provides the following "
      ++ " transpilers: stripping Flow types, object spread & rest operators, "
      ++ "class properties (including statics), class/method decorators, and "
      ++ "React-assumed JSX conversion. 'builtin' may be skipped when setting "
      ++ "this option, i.e. '\\\\.js\\$' and '\\\\.js\\$:builtin' are "
      ++ "absolutely equal. An example of using the Webpack loader: "
      ++ "'\\\\.js\\$:babel-loader?filename=.babelrc'.";

    let docv = "PATTERN:PROCESSOR?OPTIONS[!...]";
    Arg.(
      value & opt_all(preprocess, []) & info(["preprocess"], ~docv, ~doc)
    );
  };

  let envVarT = {
    let envVar = Arg.conv(EnvVar.(parse, print));
    let doc =
      "Specify which variables can be included in the resulting bundle"
      ++ "from the environment. The form is ENVVAR=DEFAULT_VALUE or just ENVVAR."
      ++ "In the latter case the default value is \"\"(empty string). If ENV_VAR"
      ++ " is set in the environment its value will be included. Otherwise, the"
      ++ " default value is used. The value is visible in the JavaScript code"
      ++ " as `process.env.ENVVAR` and has the string type";
    let docv = "ENVVAR[=DEFAULT_VALUE]";
    Arg.(value & opt_all(envVar, []) & info(["env-var"], ~docv, ~doc));
  };

  let exportCheckUsedImportsOnlyT = {
    let doc = "Check existance of the used imports only";
    let set = (
      Some(true),
      Arg.info(["export-check-used-imports-only"], ~doc),
    );
    Arg.(value & vflag(None, [set]));
  };

  Term.(
    const(run)
    $ configFileT
    $ cacheT
    $ entryPointsT
    $ mockT
    $ modeT
    $ nodeModulesPathsT
    $ outputDirT
    $ outputFilenameT
    $ publicPathT
    $ preprocessT
    $ envVarT
    $ projectRootDirT
    $ resolveExtensionT
    $ packageMainFieldsT
    $ exportCheckUsedImportsOnlyT
  );
};

let debugT = {
  let doc = "Print debug output";
  Arg.(value & flag & info(["d", "debug"], ~doc));
};

/* getters */
let unwrap = ({value, _}) => value;

let isCacheDisabled = ({cache: {value: cache, _}, _}) =>
  switch (cache) {
  | Cache.Use => false
  | Cache.Disable => true
  };

let entryPoints = ({entryPoints, _}) => unwrap(entryPoints);
let outputDir = ({outputDir, _}) => unwrap(outputDir);
let outputFilename = ({outputFilename, _}) => unwrap(outputFilename);
let projectRootDir = ({projectRootDir, _}) => unwrap(projectRootDir);
let publicPath = ({publicPath, _}) => unwrap(publicPath);
let mode = ({mode, _}) => unwrap(mode);
let mock = ({mock, _}) => List.map(unwrap, mock);
let nodeModulesPaths = ({nodeModulesPaths, _}) =>
  List.map(unwrap, nodeModulesPaths);
let resolveExtension = ({resolveExtension, _}) =>
  List.map(unwrap, resolveExtension);
let packageMainFields = ({packageMainFields, _}) =>
  List.map(unwrap, packageMainFields);
let preprocess = ({preprocess, _}) => List.map(unwrap, preprocess);
let envVar = ({envVar, _}) =>
  envVar
  |> M.bindings
  |> List.map(((name, value)) => (name, unwrap(value)))
  |> M.add_list(M.empty);
let exportCheckUsedImportsOnly =
  ({exportCheckUsedImportsOnly, _}) => unwrap(exportCheckUsedImportsOnly);

/* prettyPrint */

let prettyPrint =
    (
      {
        cache,
        entryPoints,
        mock,
        mode,
        nodeModulesPaths,
        outputDir,
        outputFilename,
        publicPath,
        preprocess,
        envVar,
        projectRootDir,
        resolveExtension,
        packageMainFields,
        exportCheckUsedImportsOnly,
      }: t,
    ) => {
  module Source = {
    let createElement = (~source, ~children, ()) => {
      let _ = children;
      <Pastel dim=true>
        {
          "   # "
          ++ (
            switch (source) {
            | File => "file"
            | Arg => "cli argument"
            | Default => "default value"
            }
          )
        }
      </Pastel>;
    };
  };
  module Title = {
    let createElement = (~children, ()) =>
      switch (String.concat("", children)) {
      | "" => ""
      | title => <Pastel bold=true> {title ++ ":\n  "} </Pastel>
      };
  };
  module P = {
    let createElement = (~json=true, ~title, ~value, ~children, ()) => {
      let {value, source} = value;
      let _ = children;
      <Pastel>
        <Title> title </Title>
        {json ? Yojson.Safe.to_string(`String(value)) : value}
        <Source source />
        "\n"
      </Pastel>;
    };
  };
  module Mode_ = {
    let createElement = (~value, ~children, ()) => {
      let _ = children;
      let {value, source} = value;
      let value = {value: Mode.toString(value), source};
      <P title="Mode" value />;
    };
  };
  module Cache_ = {
    let createElement = (~value, ~children, ()) => {
      let _ = children;
      let {value, source} = value;
      let value = {value: Cache.toString(value), source};
      <P title="Cache" value />;
    };
  };
  module EntryPoints_ = {
    let createElement = (~value, ~children, ()) => {
      let _ = children;
      let {value, source} = value;
      let value = {
        value:
          Yojson.Safe.to_string(`List(List.map(v => `String(v), value))),
        source,
      };
      <P title="Entry Points" json=false value />;
    };
  };

  module L = {
    let createElement = (~title, ~empty, ~items, ~children, ()) => {
      let _ = children;
      <Pastel>
        <Title> title </Title>
        {
          List.length(items) == 0 ?
            empty :
            List.map(
              ({source, value}) =>
                <Pastel> "- " value <Source source /> </Pastel>,
              items,
            )
            |> String.concat("\n  ")
        }
        "\n"
      </Pastel>;
    };
  };

  module NodeModulesPaths_ = {
    let createElement = (~paths, ~children, ()) => {
      let _ = children;
      <L
        title="Look For Packages In These Locations"
        empty="No paths defined to search for package dependencies!"
        items=paths
      />;
    };
  };

  module ResolveExtension_ = {
    let createElement = (~exts, ~children, ()) => {
      let _ = children;
      <L
        title="Try Extensions When Resolving"
        empty="No automatic addition of the extension when resolving modules!"
        items=exts
      />;
    };
  };

  module PackageMainFields_ = {
    let createElement = (~fields, ~children, ()) => {
      let _ = children;
      <L
        title="Use these package.json fields to determine package entry point"
        empty="Always use ./index.js"
        items=fields
      />;
    };
  };

  module Mock_ = {
    let createElement = (~mocks, ~children, ()) => {
      let _ = children;
      <L
        title="Mocks"
        empty="No mocks defined"
        items={
          List.map(
            ({value, source}) => {value: Mock.toString(value), source},
            mocks,
          )
        }
      />;
    };
  };

  module EnvVar_ = {
    let createElement = (~vars, ~children, ()) => {
      let _ = children;
      <L
        title="Inlined Environment Variables"
        empty="No env. variables inlined"
        items={
          List.map(
            ((name, {value, source})) => {
              value: name ++ "=" ++ value,
              source,
            },
            vars,
          )
        }
      />;
    };
  };

  module Preprocess_ = {
    let createElement = (~preprocess, ~children, ()) => {
      let _ = children;
      <L
        title="Preprocessors"
        empty="No preprocessors defined"
        items=Preprocessor.(
          List.map(
            ({value: p, source}) => {
              value:
                (isCatchAll(p) ? "default" : "Regexp(" ++ p.pattern_s ++ ")")
                ++ ": "
                ++ String.concat("!", p.Preprocessor.processors),
              source,
            },
            preprocess,
          )
        )
      />;
    };
  };

  <Pastel>
    <EntryPoints_ value=entryPoints />
    <P title="Project Root Directory" value=projectRootDir />
    <P title="Output Directory" value=outputDir />
    <P title="Output Filename" value=outputFilename />
    <P title="Public Path" value=publicPath />
    <P
      title="Check Only Used Exports"
      json=false
      value={
        source: exportCheckUsedImportsOnly.source,
        value: string_of_bool(exportCheckUsedImportsOnly.value),
      }
    />
    <Mode_ value=mode />
    <Cache_ value=cache />
    <NodeModulesPaths_ paths=nodeModulesPaths />
    <ResolveExtension_ exts=resolveExtension />
    <PackageMainFields_ fields=packageMainFields />
    <Mock_ mocks=mock />
    <EnvVar_ vars={M.bindings(envVar)} />
    <Preprocess_ preprocess />
  </Pastel>;
};
