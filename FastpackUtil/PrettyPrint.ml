type t = item list
and item = | String of string
           | Style of Fmt.style

let empty = []

let string s text =
  (String s) :: text

let nl text =
  (String "\n") :: text

let normal text =
  (Style `None) :: text

let red text =
  (Style `Red) :: text

let bold text =
  (Style `Bold) :: text

let add message text =
  message @ text

let pp ~ppf (text: t) =
  text
  |> List.rev
  |> List.fold_left (fun fmt item ->
      match item with
      | Style style -> Fmt.styled style fmt
      | String string -> fmt ppf string; fmt
    )
    Fmt.string
  |> ignore
