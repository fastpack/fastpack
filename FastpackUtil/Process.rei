type t
exception NotRunning(string)

let start: (~env: list((string, string))=?, array(string)) => t;

let finalize: t => Lwt.t(unit);

let write: (string, t) => Lwt.t(unit);
let readLine: t => Lwt.t(string);

let writeValue: ('a, t) => Lwt.t(unit);
let writeAndReadValue: (~msg: string=?,'a, t) => Lwt.t('b);
