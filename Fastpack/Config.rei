type t;

exception ExitError(string);
module Mock: {
  type t =
    | Empty
    | Mock(string);

  let toString: ((string, t)) => string;
}

module Preprocessor: {
  type t = {
    pattern_s: string,
    pattern: Re.re,
    processors: list(string),
  };

  let toString: t => string;
  let ofString: string => t;
}

let term: Cmdliner.Term.t(Lwt.t(t));
let debugT: Cmdliner.Term.t(bool);


let isCacheDisabled: t => bool;
let entryPoints: t => list(string)
let outputDir: t => string
let outputFilename: t => string
let projectRootDir: t => string
let publicPath: t => string
let mode: t => Mode.t
let mock: t => list((string, Mock.t));
let nodeModulesPaths: t => list(string);
let resolveExtension: t => list(string);
let preprocess: t => list(Preprocessor.t);
let envVar: t => CCMap.Make(String).t(string);

let prettyPrint: t => string;
