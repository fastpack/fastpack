
(**
 * Computation with structured error reporting.
 *)
type 'a t = ('a, error) result
and error = string * context
and context = {
  suggestion : string option;
  lines : string list;
}

let emptyContext = {
  suggestion = None;
  lines = []
}

let return v =
  Ok v

let error msg =
  Error (msg, emptyContext)

let bind ~f v = match v with
  | Ok v -> f v
  | Error err -> Error err

module Syntax = struct
  let return = return
  let error = error
  module Let_syntax = struct
    let bind = bind
  end
end

let withContext line v =
  match v with
  | Ok v -> Ok v
  | Error (msg, context) ->
    Error (msg, { context with lines = line :: context.lines })

let with_suggestion suggestion v =
  match v with
  | Ok v -> Ok v
  | Error (msg, context) ->
    Error (msg, { context with suggestion = Some suggestion })


let liftOfStringError v =
  match v with
  | Ok v -> Ok v
  | Error line -> Error (line, emptyContext)

let formatError (msg, { lines; suggestion }) =
  let context =
    lines
    |> List.map (fun line -> "  " ^ line)
    |> (fun context -> "CONTEXT:" :: context)
    |> String.concat "\n"
  in
  let suggestion =
    match suggestion with
    | Some suggestion -> "\n\nSUGGESTION:\n" ^ suggestion
    | None -> ""
  in
  context ^ "\n\n" ^ msg ^ suggestion


let foldLeft ~f ~init xs =
  let rec fold acc xs =  match acc, xs with
    | Error err, _ -> Error err
    | Ok acc, [] -> Ok acc
    | Ok acc, x::xs -> fold (f acc x) xs
  in
  fold (Ok init) xs

let rec waitAll = function
  | [] -> return ()
  | x::xs ->
    let f () = waitAll xs in
    bind ~f x
