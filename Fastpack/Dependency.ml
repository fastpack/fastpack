type t = {
  (** Original request to a dependency *)
  request : string;
  (** The filename this dependency was requested from *)
  requested_from_filename : string;
}

let resolve request =
  let basedir = FilePath.dirname request.requested_from_filename in
  FastpackResolver.resolve request.request basedir

let compare a b = compare
    (a.request, a.requested_from_filename)
    (b.request, b.requested_from_filename)
