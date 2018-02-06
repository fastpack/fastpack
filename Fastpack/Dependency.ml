
type t = {
  (** Original request to a dependency *)
  request : string;
  (** The filename this dependency was requested from *)
  requested_from_filename : string;
}


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
