type t
exception NotRunning(string)

let start: string => t;
let finalize: t => Lwt.t(unit);

let write: (string, t) => Lwt.t(unit);
let readLine: t => Lwt.t(string);

let writeAndReadValue: ('a, t) => Lwt.t('b);
