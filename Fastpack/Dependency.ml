type t = {
  (** Original request to a dependency *)
  request : string;
  (** The filename this dependency was requested from *)
  requested_from_filename : string;
}

let resolve resolver request =
  match request.request with
  | "os"| "module" | "path" | "util" | "fs" | "tty" | "net" | "events" | "__fastpack_runtime__" ->
    Lwt.return_some ("builtin:" ^ request.request)
  | _ ->
    let basedir = FilePath.dirname request.requested_from_filename in
    resolver.FastpackUtil.NodeResolve.resolve request.request basedir

let compare a b = compare
    (a.request, a.requested_from_filename)
    (b.request, b.requested_from_filename)

let to_string ?(dir=None) { request; requested_from_filename } =
  let s =
    Printf.sprintf "'%s' from file: %s" request requested_from_filename
  in
  match dir with
  | None ->
    s
  | Some dir ->
    String.replace ~sub:(dir ^ "/") ~by:"" s
