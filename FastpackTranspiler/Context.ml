type t = {
  gen_id : string -> unit -> string;
}

let create () =
  let counter = ref 0 in
  let gen_id prefix () =
    counter := 1 + !counter;
    prefix ^ (string_of_int !counter);
  in
  { gen_id; }

