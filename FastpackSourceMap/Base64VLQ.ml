let of_char = function
  | 'A' -> 0
  | 'B' -> 1
  | 'C' -> 2
  | 'D' -> 3
  | 'E' -> 4
  | 'F' -> 5
  | 'G' -> 6
  | 'H' -> 7
  | 'I' -> 8
  | 'J' -> 9
  | 'K' -> 10
  | 'L' -> 11
  | 'M' -> 12
  | 'N' -> 13
  | 'O' -> 14
  | 'P' -> 15
  | 'Q' -> 16
  | 'R' -> 17
  | 'S' -> 18
  | 'T' -> 19
  | 'U' -> 20
  | 'V' -> 21
  | 'W' -> 22
  | 'X' -> 23
  | 'Y' -> 24
  | 'Z' -> 25
  | 'a' -> 26
  | 'b' -> 27
  | 'c' -> 28
  | 'd' -> 29
  | 'e' -> 30
  | 'f' -> 31
  | 'g' -> 32
  | 'h' -> 33
  | 'i' -> 34
  | 'j' -> 35
  | 'k' -> 36
  | 'l' -> 37
  | 'm' -> 38
  | 'n' -> 39
  | 'o' -> 40
  | 'p' -> 41
  | 'q' -> 42
  | 'r' -> 43
  | 's' -> 44
  | 't' -> 45
  | 'u' -> 46
  | 'v' -> 47
  | 'w' -> 48
  | 'x' -> 49
  | 'y' -> 50
  | 'z' -> 51
  | '0' -> 52
  | '1' -> 53
  | '2' -> 54
  | '3' -> 55
  | '4' -> 56
  | '5' -> 57
  | '6' -> 58
  | '7' -> 59
  | '8' -> 60
  | '9' -> 61
  | '+' -> 62
  | '/' -> 63
  | '=' -> 64
  | _ -> raise (Invalid_argument "invalid argument")

let to_char = function
  |  0 -> 'A'
  |  1 -> 'B'
  |  2 -> 'C'
  |  3 -> 'D'
  |  4 -> 'E'
  |  5 -> 'F'
  |  6 -> 'G'
  |  7 -> 'H'
  |  8 -> 'I'
  |  9 -> 'J'
  |  10 -> 'K'
  |  11 -> 'L'
  |  12 -> 'M'
  |  13 -> 'N'
  |  14 -> 'O'
  |  15 -> 'P'
  |  16 -> 'Q'
  |  17 -> 'R'
  |  18 -> 'S'
  |  19 -> 'T'
  |  20 -> 'U'
  |  21 -> 'V'
  |  22 -> 'W'
  |  23 -> 'X'
  |  24 -> 'Y'
  |  25 -> 'Z'
  |  26 -> 'a'
  |  27 -> 'b'
  |  28 -> 'c'
  |  29 -> 'd'
  |  30 -> 'e'
  |  31 -> 'f'
  |  32 -> 'g'
  |  33 -> 'h'
  |  34 -> 'i'
  |  35 -> 'j'
  |  36 -> 'k'
  |  37 -> 'l'
  |  38 -> 'm'
  |  39 -> 'n'
  |  40 -> 'o'
  |  41 -> 'p'
  |  42 -> 'q'
  |  43 -> 'r'
  |  44 -> 's'
  |  45 -> 't'
  |  46 -> 'u'
  |  47 -> 'v'
  |  48 -> 'w'
  |  49 -> 'x'
  |  50 -> 'y'
  |  51 -> 'z'
  |  52 -> '0'
  |  53 -> '1'
  |  54 -> '2'
  |  55 -> '3'
  |  56 -> '4'
  |  57 -> '5'
  |  58 -> '6'
  |  59 -> '7'
  |  60 -> '8'
  |  61 -> '9'
  |  62 -> '+'
  |  63 -> '/'
  |  64 -> '='
  | _ -> raise (Invalid_argument "invalid argument")

let encode_int buf value =
  let value = if value < 0 then (-value) lsl 1 else value lsl 1 in
  let rec encode value =
    let clamped = value land 31 in
    let value = value lsr 5 in
    let clamped = if value > 0 then clamped lor 32 else clamped in
    Buffer.add_char buf (to_char clamped);
    if value > 0 then encode value else ();
  in
  encode value

let encode value =
  let buf = Buffer.create (List.length value) in
  List.iter (fun value -> encode_int buf value) value;
  Buffer.to_bytes buf

let decode string =
  let result = ref [] in
  let shift = ref 0 in
  let value = ref 0 in
  Bytes.iter
    (fun char ->
       let num = of_char char in
       let has_continuation_bit = (num land 32) != 0 in
       let num = num land 31 in
       value := !value + (num lsl !shift);
       if has_continuation_bit then
         shift := !shift + 5
       else
         let should_negate = (!value land 1) != 0 in
         value := !value lsr 1;
         result := (if should_negate then -(!value) else !value)::(!result);
         value := 0;
         shift := 0
    )
    string;
  List.rev !result
