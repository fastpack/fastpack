module Mock: {
  type t =
    | Empty
    | Mock(string);
  let to_string: t => string;
  let parse: string => result((bool, (string, t)), [> | `Msg(string)]);
  let print: (Format.formatter, ('a, (string, t))) => unit;
};

type t = {
  resolve:
    (~basedir: string, string) => Lwt.t((Module.location, list(string))),
};

exception Error(string);

let make:
  (
    ~project_root: string,
    ~current_dir: string,
    ~mock: list((string, Mock.t)),
    ~node_modules_paths: list(string),
    ~extensions: list(string),
    ~preprocessor: Preprocessor.t,
    ~cache: Cache.t
  ) =>
  t;
