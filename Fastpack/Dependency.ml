
type t = {
  (** Original request to a dependency *)
  request : string;
  (** The filename this dependency was requested from *)
  requested_from : requested_from;
}
and requested_from = | EntryPoint | Filename of string

let compare = Pervasives.compare


let to_string ?(dir=None) { request; requested_from } =
  let requested_from =
    match requested_from with
    | EntryPoint -> ""
    | Filename filename -> Printf.sprintf " from file: %s" filename
  in
  let s =
    Printf.sprintf "'%s'%s" request requested_from
  in
  match dir with
  | None ->
    s
  | Some dir ->
    String.replace ~sub:(dir ^ "/") ~by:"" s
