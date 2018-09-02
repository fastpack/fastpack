open Cmdliner;

module Cache = {
  type t =
    | Use
    | Disable;
};

module Mock = {
  type t =
    | Empty
    | Mock(string);

  let to_string = mock =>
    switch (mock) {
    | Empty => ""
    | Mock(mock) => mock
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

  let print = (ppf, (_, mock)) => {
    let value =
      switch (mock) {
      | (request, Empty) => request
      | (request, Mock(mock)) => request ++ ":" ++ mock
      };

    Format.fprintf(ppf, "%s", value);
  };
};

module Reporter = {
  type t =
    | JSON
    | Text;
};

type t = {
  entryPoints: list(string),
  outputDir: string,
  outputFilename: string,
  mode: Mode.t,
  mock: list((string, Mock.t)),
  nodeModulesPaths: list(string),
  projectRootDir: string,
  resolveExtension: list(string),
  target: Target.t,
  cache: Cache.t,
  preprocess: list(Preprocessor.config),
  postprocess: list(string),
  report: Reporter.t,
  debug: bool,
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
  entryPoints,
  outputDir,
  outputFilename,
  mode,
  mock,
  nodeModulesPaths,
  projectRootDir,
  resolveExtension,
  target,
  cache,
  preprocess,
  postprocess,
  report,
  debug,
};

let term = {
  let run =
      (
        entryPoints,
        outputDir,
        outputFilename,
        mode,
        mock,
        nodeModulesPaths,
        projectRootDir,
        resolveExtension,
        target,
        cache,
        preprocess,
        postprocess,
        report,
        debug,
      ) =>
    create(
      ~entryPoints,
      ~outputDir,
      ~outputFilename,
      ~mode,
      ~mock=List.map(snd, mock),
      ~nodeModulesPaths,
      ~projectRootDir,
      ~resolveExtension,
      ~target,
      ~cache,
      ~preprocess=List.map(snd, preprocess),
      ~postprocess,
      ~report,
      ~debug,
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
    module P = Preprocessor;
    let preprocess = {
      let parse = s =>
        try (Result.Ok((false, P.of_string(s)))) {
        | Failure(msg) => Result.Error(`Msg(msg))
        };

      let print = (ppf, (_, opt)) =>
        Format.fprintf(ppf, "%s", P.to_string(opt));

      Arg.conv((parse, print));
    };

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
    $ entryPointsT
    $ outputDirT
    $ outputFilenameT
    $ modeT
    $ mockT
    $ nodeModulesPathsT
    $ projectRootDirT
    $ resolveExtensionT
    $ targetT
    $ cacheT
    $ preprocessT
    $ postprocessT
    $ reportT
    $ debugT
  );
};
