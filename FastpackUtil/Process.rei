type t
exception NotRunning(string)

let start: array(string) => t;
let finalize: t => Lwt.t(unit);

let write: (string, t) => Lwt.t(unit);
let readLine: t => Lwt.t(string);

let writeAndReadValue: (~msg: string=?,'a, t) => Lwt.t('b);
