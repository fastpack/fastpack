type t;
exception Error(string);
let make: (
  ~project_root: string,
  ~current_dir: string,
  ~output_dir: string,
  unit
  ) => Lwt.t(t);

let run:
  (Module.location, option(string), t)
  => Lwt.t((string, list(string), list(string)))

let finalize: t => Lwt.t(unit);
