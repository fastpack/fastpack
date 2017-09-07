type t = {
  gen_id : string -> unit -> string;
  require_runtime : unit -> unit;
  is_runtime_required : unit -> bool;
}

let create () =
  let counter = ref 0 in
  let runtime_required = ref false in
  let gen_id prefix () =
    counter := 1 + !counter;
    prefix ^ (string_of_int !counter);
  in
  let is_runtime_required () =
    !runtime_required
  in
  let require_runtime () =
    runtime_required := true
  in
  { gen_id; require_runtime; is_runtime_required; }

