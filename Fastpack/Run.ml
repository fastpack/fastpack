
(**
 * Computation with structured error reporting.
 *)
type 'a t = ('a, error) result
and error = string * context
and context = string list

let return v =
  Ok v

let error msg =
  Error (msg, [])

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
  | Error (msg, context) -> Error (msg, line::context)

let liftOfStringError v =
  match v with
  | Ok v -> Ok v
  | Error line -> Error (line, [])

let formatError (msg, context) =
  context
  |> List.map (fun line -> "  " ^ line)
  |> (fun context -> msg :: context)
  |> String.concat "\n"


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
