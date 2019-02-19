type t
type load =
  | Empty
  | Load(params)
and params = {
  currentDir: string,
  projectRootDir: string,
  mock: list((string, Config.Mock.t)),
  nodeModulesPaths: list(string),
  resolveExtension: list(string),
  preprocess: list(Config.Preprocessor.t),
};

let make: load => Lwt.t(t);
let isLoadedEmpty: t => bool;
let addModule: (Module.t, t) => unit;
let getModule: (Module.location, t) => Lwt.t(option(Module.t));
let removeModule: (Module.location, t) => unit;
let save: t => Lwt.t(unit);
let getFilename: t => option(string);

module File: {
  type exactMatch = FSCache.exactMatch;
  let invalidate: (string, t) => Lwt.t(unit);
  let exists: (string, t) => Lwt.t(bool);
  let caseSensitiveExactMatch: (string, t) => Lwt.t(exactMatch);
  let stat: (string, t) => Lwt.t(option(Unix.stats));
  let readExisting: (string, t) => Lwt.t(string);
  let read: (string, t) => Lwt.t(option(string));
};
