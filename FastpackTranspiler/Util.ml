type direction = GoForward | GoBackward

type scope = {
  tmp_var : unit -> string;
}

let find_string_start ?(direction=GoBackward) what sub start =
  let len = String.length what in
  let step = if direction = GoForward then 1 else -1 in
  let rec next pos =
    let s = sub pos len in
    if s = what
      then Some pos
      else if pos = 0
        then None
        else next @@ pos + step
  in
  next @@ start + step

let find_comma_pos ?(direction=GoBackward) sub start =
  let step = if direction = GoForward then 1 else -1 in
  let rec next pos =
    let s = sub pos 1 in
    match s with
    | "," -> Some (pos + (if direction = GoForward then 1 else 0))
    | " " | "\n" | "\r" -> next @@ pos + step
    | _ -> None
  in
  next @@ start + (if direction = GoBackward then step else 0)

let removeProps object_name props =
  Printf.sprintf "$fpack.removeProps(%s, [%s])"
    object_name
    @@ String.concat ", " props

let make_scope () =
  let i = ref 0 in
  (*
   * let tmp_var cur_scope = check name in scope
   * *)
  let tmp_var () =
    i := !i + 1;
    "$$fpack_" ^ (string_of_int !i)
  in
  { tmp_var; }
