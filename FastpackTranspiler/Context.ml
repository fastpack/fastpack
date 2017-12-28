module Scope = FastpackUtil.Scope

type t = {
  gen_id : string -> unit -> string;
  gen_binding : Scope.t -> string;
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
  let rec gen_binding scope =
    let name = gen_id "__fpack__" () in
    if (Scope.has_binding name scope) then (gen_binding scope) else name
  in
  { gen_id; gen_binding; require_runtime; is_runtime_required; }

