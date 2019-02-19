type t;
type exactMatch =
  | Exact
  | CaseInsensitive(string, list(string))
  | CaseInsensitiveUTF(string)
  | MisMatch;


let make: unit => t;
let isEmpty: t => bool;
let clear: t => unit;

let read: (string, t) => Lwt.t(option(string));
let readExisting: (string, t) => Lwt.t(string);
let stat: (string, t) => Lwt.t(option(Unix.stats));
let exists: (string, t) => Lwt.t(bool);
let caseSensitiveExactMatch: (string, t) => Lwt.t(exactMatch);
let invalidate: (string, t) => Lwt.t(unit);

type persistent
let toPersistent: t => persistent
let ofPersistent: persistent => t

/*
 type status =
   | Fresh
   | Cached;

 let readWithStatus: (string, t) => Lwt.t((status, string));
 let statWithStatus: (string, t) => Lwt.t(option((status, Unix.stats)));
 */
