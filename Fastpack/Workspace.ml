(**

   This module implements workspace, an original string and a set of patches
   over it.

*)

type 'ctx t = {

  (* Original string value *)
  value : string;

  (* List of patches sorted in desceding order *)
  patches: 'ctx patch list;
}

and 'ctx patch = {

  (* Start offset into an original value *)
  offset_start : int;

  (* End offset into an original value *)
  offset_end : int;

  (* Patch to apply *)
  patch : 'ctx -> string;
}

type 'ctx patcher = {
  patch_with : int -> int -> ('ctx -> string) -> unit;
  patch : int -> int -> string -> unit;
  remove : int -> int -> unit;
  patch_loc_with : Loc.t -> ('ctx -> string) -> unit;
  patch_loc : Loc.t -> string -> unit;
  remove_loc : Loc.t -> unit;
  sub : int -> int -> string;
  sub_loc : Loc.t -> string;
}

let of_string s =
  { value = s; patches = []; }

let patch w p =
  { w with patches = p::w.patches }

let write out w ctx =
  let patches = List.rev w.patches in
  let rec write_patch offset value patches =
    match patches with
    | [] ->
      Lwt_io.write_from_exactly out value offset (String.length value - offset)
    | patch::patches ->
      let%lwt () = Lwt_io.write_from_exactly out value offset (patch.offset_start - offset) in
      let%lwt () = Lwt_io.write out (patch.patch ctx) in
      write_patch patch.offset_end value patches
  in
  write_patch 0 w.value patches

let to_string w ctx =
  let patches = List.rev w.patches in
  let rec print offset value patches =
    match patches with
    | [] ->
      String.sub value offset (String.length value - offset)
    | patch::patches ->
      let patch_pre = String.sub value offset (patch.offset_start - offset) in
      patch_pre ^ (patch.patch ctx) ^ (print patch.offset_end value patches)
  in
  print 0 w.value patches

let make_patcher workspace =
  let patch_with start offset f =
    let _end = start + offset in
    begin
      workspace := patch !workspace {
        patch = f;
        offset_start = min start _end;
        offset_end = max start _end;
      }
    end
  in
  let patch start offset s = patch_with start offset (fun _ -> s) in
  let remove start offset = patch start offset "" in
  let patch_loc_with (loc: Loc.t) f =
    patch_with loc.start.offset (loc._end.offset - loc.start.offset) f
  in
  let patch_loc (loc: Loc.t) s =
    patch loc.start.offset (loc._end.offset - loc.start.offset) s
  in
  let remove_loc (loc: Loc.t) =
    remove loc.start.offset (loc._end.offset - loc.start.offset)
  in
  let sub start len = String.sub (!workspace).value start len in
  let sub_loc (loc : Loc.t) =
    sub (loc.start.offset) (loc._end.offset - loc.start.offset)
  in {
    patch_with;
    patch;
    remove;
    patch_loc_with;
    patch_loc;
    remove_loc;
    sub;
    sub_loc;
  }
