
type t =
  | Builtin
  | Base64Url of string
  | Webpack of (string * string)

let of_string str =
  String.(str |> split_on_char '!')
  |> List.filter_map (fun s ->
    let s = String.trim s in
    match s = "" with
    | true -> None
    | false ->
      match String.split_on_char '?' s  with
      | [] ->
        raise (Failure "Empty processor")
      | "to-base64-url" :: [] ->
        Some (Base64Url "")
      | processor :: [] ->
        Some (Webpack (processor, ""))
      | "builtin" :: "" :: [] ->
        Some Builtin
      | processor :: opts :: [] when processor <> "builtin" ->
        Some (Webpack (processor, opts))
      | _ ->
        raise (Failure "Incorrect preprocessor config")
  )

let to_string = function
 | Builtin -> "builtin"
 | Base64Url opts ->
  let p = "to-base64-url" in
  let opt = if opts <> "" then "?" ^ opts else "" in
  p ^ opt
 | Webpack (loader, opts) ->
  let opt = if opts <> "" then "?" ^ opts else "" in
  loader ^ opt

let to_string_list = List.map to_string

let to_base64 file =
  let data = B64.encode file in
  let export = "module.exports = \"data:image/svg+xml;base64," ^ data ^ "\"" in
  export
