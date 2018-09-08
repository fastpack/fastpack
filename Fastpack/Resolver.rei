type t;
exception Error(string);

let make:
  (
    ~project_root: string,
    ~current_dir: string,
    ~mock: list((string, Config.Mock.t)),
    ~node_modules_paths: list(string),
    ~extensions: list(string),
    ~preprocessors: list(Config.Preprocessor.t),
    ~cache: Cache.t,
    unit
  ) =>
  t;

let resolve:
  (~basedir: string, string, t) => Lwt.t((Module.location, list(string)));
