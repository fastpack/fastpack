type t = {
  (** Original request to a dependency *)
  request : string;
  (** The filename this dependency was requested from *)
  requested_from_filename : string;
}

let resolve request =
  match request.request with
  | "util" | "fs" | "tty" | "net" | "events" ->
    Lwt.return_some ("builtin:" ^ request.request)
  | _ ->
    let basedir = FilePath.dirname request.requested_from_filename in
    FastpackResolver.resolve request.request basedir

let compare a b = compare
    (a.request, a.requested_from_filename)
    (b.request, b.requested_from_filename)

let to_string { request; requested_from_filename } =
  Printf.sprintf "'%s' from file: %s" request requested_from_filename
