module StringSet = Set.Make(String)

type t = {
  (** Original request to a dependency *)
  request : string;
  (** The filename this dependency was requested from *)
  requested_from_filename : string;
}

let builtins =
  StringSet.empty
  |> StringSet.add "__fastpack_runtime__"
  |> StringSet.add "os"
  |> StringSet.add "module"
  |> StringSet.add "path"
  |> StringSet.add "util"
  |> StringSet.add "fs"
  |> StringSet.add "tty"
  |> StringSet.add "net"
  |> StringSet.add "events"
  |> StringSet.add "assert"
  |> StringSet.add "stream"
  |> StringSet.add "constants"
  |> StringSet.add "readable-stream"

let is_builtin module_request =
  StringSet.mem module_request builtins

let resolve resolver request =
  match is_builtin request.request with
  | true ->
    Lwt.return_some ("builtin:" ^ request.request)
  | false ->
    let basedir = FilePath.dirname request.requested_from_filename in
    resolver.NodeResolver.resolve request.request basedir

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
