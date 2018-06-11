
(**
 * Computation with structured error reporting.
 *)
type 'a t = ('a, error) result
and error = PrettyPrint.t * context
and context = {
  suggestion : PrettyPrint.t option;
  lines : string list;
}

let emptyContext = {
  suggestion = None;
  lines = []
}

let pp_error ?(ppf=Format.err_formatter) ((message : PrettyPrint.t), context) =
  let open PrettyPrint in
  let indent = "  " in
  let title s = fun text -> text |> bold |> string s |> normal |> nl in
  let pp_context = fun text ->
    match context.lines with
    | [] -> text
    | lines ->
      List.fold_left
        (fun text line -> text |> string (indent ^ line) |> nl)
        (text |> title "CONTEXT:")
        lines
  in
  let pp_suggestion = fun text ->
    match context.suggestion with
    | Some suggestion -> text |> nl |> title "SUGGESTION:" |> add suggestion
    | None -> text
  in
  let text = empty |> pp_context |> add message |> pp_suggestion in
  pp ~ppf text


let return v =
  Ok v

let error error =
  Error (error, emptyContext)

let error_str msg =
  let open PrettyPrint in
  error (empty |> bold |> red |> string msg |> normal)

let bind ~f v = match v with
  | Ok v -> f v
  | Error err -> Error err

module Syntax = struct
  let return = return
  let error = error
  let error_str = error_str
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

let formatError error =
  pp_error ~ppf:Format.str_formatter error;
  Format.flush_str_formatter ()
  (* let context = *)
  (*   lines *)
  (*   |> List.map (fun line -> "  " ^ line) *)
  (*   |> (fun context -> "CONTEXT:" :: context) *)
  (*   |> String.concat "\n" *)
  (* in *)
  (* let suggestion = *)
  (*   match suggestion with *)
  (*   | Some suggestion -> "\n\nSUGGESTION:\n" ^ suggestion *)
  (*   | None -> "" *)
  (* in *)
  (* context ^ "\n\n" ^ msg ^ suggestion *)


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
