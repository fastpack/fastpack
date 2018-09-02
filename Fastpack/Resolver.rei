type t = {
  resolve:
    (~basedir: string, string) => Lwt.t((Module.location, list(string))),
};

exception Error(string);

let make:
  (
    ~project_root: string,
    ~current_dir: string,
    ~mock: list((string, Config.Mock.t)),
    ~node_modules_paths: list(string),
    ~extensions: list(string),
    ~preprocessor: Preprocessor.t,
    ~cache: Cache.t
  ) =>
  t;
