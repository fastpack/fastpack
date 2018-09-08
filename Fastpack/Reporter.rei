type file = {
  name: string,
  size: int,
};
type onOk =
  (
    ~message: option(string),
    ~start_time: float,
    ~files: list(file),
    Context.t
  ) =>
  Lwt.t(unit);
type onError = (~error: Error.reason, Context.t) => Lwt.t(unit);
type t;

let make: (onOk, onError, unit) => t;
let reportOk:
  (
    ~message: option(string),
    ~start_time: float,
    ~files: list(file),
    ~ctx: Context.t,
    t
  ) =>
  Lwt.t(unit);
let reportError: (~error: Error.reason, ~ctx: Context.t, t) => Lwt.t(unit);


module Text: {
  let make: unit => t;
}

module JSON: {
  let make: unit => t;
}
