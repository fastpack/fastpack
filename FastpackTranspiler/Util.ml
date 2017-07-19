type direction = GoForward | GoBackward

let find_comma_pos ?(direction=GoBackward) sub start =
  let step = if direction = GoForward then 1 else -1 in
  let rec next pos =
    let s = sub pos 1 in
    match s with
    | "," -> Some pos
    | " " | "\n" | "\r" -> next @@ pos + step
    | _ -> None
  in
  next @@ start + step

let removeProps object_name props =
  Printf.sprintf "$fpack.removeProps(%s, [%s])"
    object_name
    @@ String.concat ", " props
