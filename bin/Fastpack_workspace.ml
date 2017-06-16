(**

   This module implements workspace, an original string and a set of patches
   over it.

*)

type t = {

  (* Original string value *)
  value : string;

  (* List of patches sorted in desceding order *)
  patches: patch list;
}

and patch = {

  (* Start offset into an original value *)
  offset_start : int;

  (* End offset into an original value *)
  offset_end : int;

  (* Patch to apply *)
  patch : string;
}

let of_string s =
  {
    value = s;
    patches = [];
  }

let rec to_string w =
  let patches = List.rev w.patches in
  let rec print offset value patches =
    print_endline ("OFFSET: " ^ (string_of_int offset));
    match patches with
    | [] ->
      String.sub value offset (String.length value - 1)
    | patch::patches ->
      print_endline (string_of_int patch.offset_start);
      print_endline (string_of_int patch.offset_end);
      let patch_pre = String.sub value offset (patch.offset_start - offset) in
      print_endline patch_pre;
      patch_pre ^ patch.patch ^ (print patch.offset_end value patches)
  in
  print 0 w.value patches

let patch w p =
  {
    w with patches = p::w.patches
  }
