(*
 * Flow parser does the check for malformed Unicode.
 * Here we just stupidly consider all the unicode as well-formed.
 * *)


let is_symbol b =
  let b = Char.code b in
  b < 0x80 || b > 0xbf

let length s =
  String.length @@ CCString.filter is_symbol s

let sub s u_offset u_length =
  let length = String.length s in
  let rec skip s pos n =
    if n = 0 then pos else skip_tail s (pos + 1) (n - 1)
  and skip_tail s pos n =
    if pos = length then skip s length 0
    else if is_symbol (String.get s pos) then skip s pos n
    else skip_tail s (pos + 1) n
  in
  let b_start = skip s 0 u_offset in
  let b_end = skip s b_start u_length in
  String.sub s b_start (b_end - b_start)
