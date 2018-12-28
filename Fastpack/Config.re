open Cmdliner;
module FS = FastpackUtil.FS;

exception ExitError(string);

module Cache = {
  type t =
    | Use
    | Disable;
};

module Mock = {
  type t =
    | Empty
    | Mock(string);

  let to_string = ((request, mock)) =>
    switch (mock) {
    | Empty => request
    | Mock(mock) => request ++ ":" ++ mock
    };

  let parse = s =>
    switch (String.(s |> trim |> split_on_char(':'))) {
    | []
    | [""] => Result.Error(`Msg("Empty config"))
    | [request]
    | [request, ""] => Result.Ok((false, (request, Empty)))
    | [request, ...rest] =>
      let mock = String.concat(":", rest);
      Result.Ok((false, (request, Mock(mock))));
    };

  let print = (ppf, (_, mock)) =>
    Format.fprintf(ppf, "%s", to_string(mock));
};

module Reporter = {
  type t =
    | JSON
    | Text;
};

module Preprocessor = {
  type t = {
    pattern_s: string,
    pattern: Re.re,
    processors: list(string),
  };

  let ofString = s => {
    let (pattern_s, processors) =
      switch (String.(s |> trim |> split_on_char(':'))) {
      | []
      | [""] => raise(Failure("Empty config"))
      | [pattern_s]
      | [pattern_s, ""] => (pattern_s, ["builtin"])
      | [pattern_s, ...rest] =>
        let processors =
          String.(rest |> concat(":") |> split_on_char('!'))
          |> CCList.filter_map(s => {
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
      try (Re.Posix.compile_pat(pattern_s)) {
      | Re.Posix.Parse_error =>
        raise(Failure("Pattern regexp parse error. Use POSIX syntax"))
      };

    {pattern_s, pattern, processors};
  };

  let toString = ({pattern_s, processors, _}) =>
    Printf.sprintf("%s:%s", pattern_s, String.concat("!", processors));
  let parse = s =>
    try (Result.Ok((false, ofString(s)))) {
    | Failure(msg) => Result.Error(`Msg(msg))
    };

  let print = (ppf, (_, opt)) => Format.fprintf(ppf, "%s", toString(opt));
};

type t = {
  cache: Cache.t,
  debug: bool,
  entryPoints: list(string),
  mock: list((string, Mock.t)),
  mode: Mode.t,
  nodeModulesPaths: list(string),
  outputDir: string,
  outputFilename: string,
  postprocess: list(string),
  preprocess: list(Preprocessor.t),
  projectRootDir: string,
  report: Reporter.t,
  resolveExtension: list(string),
  target: Target.t,
};

let create =
    (
      ~entryPoints,
      ~outputDir,
      ~outputFilename,
      ~mode,
      ~mock,
      ~nodeModulesPaths,
      ~projectRootDir,
      ~resolveExtension,
      ~target,
      ~cache,
      ~preprocess,
      ~postprocess,
      ~report,
      ~debug,
    ) => {
  let currentDir = Unix.getcwd();

  /* output directory & output filename */
  let (outputDir, outputFilename) = {
    let outputDir = FS.abs_path(currentDir, outputDir);
    let outputFilename = FS.abs_path(outputDir, outputFilename);
    let outputFilenameParent = FilePath.dirname(outputFilename);
    if (outputDir == outputFilenameParent
        || FilePath.is_updir(outputDir, outputFilenameParent)) {
      (outputDir, outputFilename);
    } else {
      let error =
        "Output filename must be a subpath of output directory.\n"
        ++ "Output directory:\n  "
        ++ outputDir
        ++ "\n"
        ++ "Output filename:\n  "
        ++ outputFilename
        ++ "\n";

      raise(ExitError(error));
    };
  };
  let projectRootDir = FastpackUtil.FS.abs_path(currentDir, projectRootDir);
  let resolveExtension =
    resolveExtension
    |> List.filter(ext => String.trim(ext) != "")
    |> List.map(ext =>
         switch (ext.[0]) {
         | '.' => ext
         | _ => "." ++ ext
         }
       );
  {
    cache,
    debug,
    entryPoints,
    mock,
    mode,
    nodeModulesPaths,
    outputDir,
    outputFilename,
    postprocess,
    preprocess,
    projectRootDir,
    report,
    resolveExtension,
    target,
  };
};

let term = {
  let run =
      (
        cache,
        debug,
        entryPoints,
        mock,
        mode,
        nodeModulesPaths,
        outputDir,
        outputFilename,
        postprocess,
        preprocess,
        projectRootDir,
        report,
        resolveExtension,
        target,
      ) =>
    create(
      ~cache,
      ~debug,
      ~entryPoints,
      ~mock=List.map(snd, mock),
      ~mode,
      ~nodeModulesPaths,
      ~outputDir,
      ~outputFilename,
      ~postprocess,
      ~preprocess=List.map(snd, preprocess),
      ~projectRootDir,
      ~report,
      ~resolveExtension,
      ~target,
    );

  let entryPointsT = {
    let doc = "Entry points. Default: ['.']";

    let docv = "ENTRY POINTS";
    Arg.(value & pos_all(string, ["."]) & info([], ~docv, ~doc));
  };

  let outputDirT = {
    let doc =
      "Output Directory. " ++ "The target bundle will be $(docv)/index.js.";

    let docv = "DIR";
    Arg.(
      value & opt(string, "./bundle") & info(["o", "output"], ~docv, ~doc)
    );
  };

  let outputFilenameT = {
    let doc =
      "Output File Name. " ++ "The target bundle filename will be $(docv)";

    let docv = "NAME";
    Arg.(
      value & opt(string, "index.js") & info(["n", "name"], ~docv, ~doc)
    );
  };

  let modeT = {
    open Mode;
    let doc = "Build bundle for development";
    let development = (Development, Arg.info(["development"], ~doc));
    Arg.(value & vflag(Production, [development]));
  };

  let nodeModulesPathsT = {
    let doc =
      "Paths to 'node_modules' directory. Should be inside the project directory."
      ++ ". Defaults to ['node_modules']";

    let docv = "PATH";
    Arg.(
      value
      & opt_all(string, ["node_modules"])
      & info(["nm", "node-modules"], ~docv, ~doc)
    );
  };

  let projectRootDirT = {
    let doc =
      "Ancestor to which node_modules will be resolved." ++ ". Defaults to '.'";

    let docv = "PATH";
    Arg.(value & opt(string, ".") & info(["project-root"], ~docv, ~doc));
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
      value
      & opt_all(string, [".js", ".json"])
      & info(["resolve-extension"], ~docv, ~doc)
    );
  };

  let targetT = {
    open Target;
    let doc = "Deployment target.";
    let docv = "[ app | esm | cjs ]";
    let target =
      Arg.enum([("app", Application), ("esm", ESM), ("cjs", CommonJS)]);

    Arg.(value & opt(target, Application) & info(["target"], ~docv, ~doc));
  };

  let cacheT = {
    let doc = "Do not use cache at all (effective in development mode only)";

    let disable = (Cache.Disable, Arg.info(["no-cache"], ~doc));
    Arg.(value & vflag(Cache.Use, [disable]));
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

  let postprocessT = {
    let doc =
      "Apply shell command on a bundle file. The content of the bundle will"
      ++ " be sent to STDIN and STDOUT output will be collected. If multiple"
      ++ " commands are specified they will be applied in the order of appearance";

    let docv = "COMMAND";
    Arg.(value & opt_all(string, []) & info(["postprocess"], ~docv, ~doc));
  };

  let reportT = {
    let doc = "Output packer statistics";
    let docv = "[ json ]";
    let report = Arg.enum(Reporter.[("json", JSON), ("text", Text)]);

    Arg.(
      value & opt(report, Reporter.Text) & info(["report"], ~docv, ~doc)
    );
  };

  let debugT = {
    let doc = "Print debug output";
    Arg.(value & flag & info(["d", "debug"], ~doc));
  };

  Term.(
    const(run)
    $ cacheT
    $ debugT
    $ entryPointsT
    $ mockT
    $ modeT
    $ nodeModulesPathsT
    $ outputDirT
    $ outputFilenameT
    $ postprocessT
    $ preprocessT
    $ projectRootDirT
    $ reportT
    $ resolveExtensionT
    $ targetT
  );
};
