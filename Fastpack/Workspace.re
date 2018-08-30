/**

   This module implements workspace, an original string and a set of patches
   over it.

*/;

module Loc = FlowParser.Loc;
module UTF8 = FastpackUtil.UTF8;

type t('ctx) = {
  /* Original string value */
  value: string,
  /* List of patches sorted in desceding order */
  patches: list(patch('ctx)),
}
and patch('ctx) = {
  /* Start offset into an original value */
  offset_start: int,
  /* End offset into an original value */
  offset_end: int,
  /* Order of appearance, important for zero-length patches */
  order: int,
  /* Patch to apply */
  patch: 'ctx => string,
};

type patcher('ctx) = {
  patch_with: (int, int, 'ctx => string) => unit,
  patch: (int, int, string) => unit,
  remove: (int, int) => unit,
  patch_loc_with: (Loc.t, 'ctx => string) => unit,
  patch_loc: (Loc.t, string) => unit,
  remove_loc: Loc.t => unit,
  sub: (int, int) => string,
  sub_loc: Loc.t => string,
};

let of_string = s => {value: s, patches: []};

let patch = (w, p) => {...w, patches: [p, ...w.patches]};

let print_patch = ({offset_start, offset_end, order, _}) =>
  Printf.printf("%d:  %d %d\n", order, offset_start, offset_end);

let print_patches = patches => {
  print_endline("---");
  List.iter(print_patch, patches);
  print_endline("---");
  patches;
};

let write =
    (
      ~modify=s => s,
      ~output_channel: Lwt_io.output_channel,
      ~workspace: t('a),
      ~ctx: 'a,
    ) =>
  switch (workspace.patches) {
  | [] =>
    let value = modify(workspace.value);
    let%lwt () = Lwt_io.write(output_channel, value);
    Lwt.return(value);
  | _ =>
    let fold_patches = patches => {
      /* The idea behind this key function is:
       * - patch with lower start position goes first
       * - then (same start positions): zero-length patches
       * - then (same start positions): ordered by length in descending order
       * - then (same length): ordered by appearance in the patch list
       * */
      let key = ({offset_start, offset_end, order, _}) => {
        let len = offset_end - offset_start;
        (offset_start, len != 0, - len, order);
      };

      let (_, folded) =
        List.fold_left(
          ((last, patches), patch) => {
            let zero_patch = patch.offset_end - patch.offset_start == 0;
            if (zero_patch) {
              (last, [patch, ...patches]);
            } else {
              switch (last) {
              | None => (Some(patch), [patch, ...patches])
              | Some(last) =>
                switch (
                  patch.offset_start < last.offset_end,
                  patch.offset_end <= last.offset_end,
                ) {
                | (true, true) => (Some(last), patches)
                | (true, false) =>
                  FastpackUtil.Error.ie("Unexpected patch combination")
                | (false, _) => (Some(patch), [patch, ...patches])
                }
              };
            };
          },
          (None, []),
        ) @@
        List.sort((p1, p2) => compare(key(p1), key(p2)), patches);

      List.rev(folded);
    };

    let patches = fold_patches(workspace.patches);
    /* let () = print_endline w.value in */
    /* let () = print_endline "----" in */
    /* let _ = print_patches patches in */
    /* let () = print_endline "----" in */
    let rec write_patch = (b_offset, u_offset, value, patches, content) =>
      switch (patches) {
      | [] =>
        let u_length = UTF8.length(value) - u_offset;
        let chunk = UTF8.sub(value, u_offset, u_length);
        let modified = modify(chunk);
        let%lwt () = Lwt_io.write(output_channel, modified);

        Lwt.return(content ++ modified);
      /* let%lwt () = */
      /*   Lwt_io.write_from_string_exactly */
      /*     output_channel */
      /*     value */
      /*     b_offset */
      /*     (String.length chunk) */
      /* in */
      /* Lwt.return (content ^ chunk) */
      | [patch, ...patches] =>
        let u_length = patch.offset_start - u_offset;
        let chunk = UTF8.sub(value, u_offset, u_length);
        let modified_chunk = modify(chunk);
        let b_length = String.length(chunk);
        let%lwt () = Lwt_io.write(output_channel, modified_chunk);
        /* let%lwt () = Lwt_io.write_from_string_exactly output_channel value b_offset b_length in */
        let patch_content = patch.patch(ctx) |> modify;
        let%lwt () = Lwt_io.write(output_channel, patch_content);
        let patched_chunk =
          UTF8.sub(
            value,
            patch.offset_start,
            patch.offset_end - patch.offset_start,
          );
        write_patch(
          b_offset + b_length + String.length(patched_chunk),
          patch.offset_end,
          value,
          patches,
          content ++ modified_chunk ++ patch_content,
        );
      };

    write_patch(0, 0, workspace.value, patches, "");
  };

let to_string = (w, ctx) => {
  let patches = List.rev(w.patches);
  let rec print = (offset, value, patches) =>
    switch (patches) {
    | [] => String.sub(value, offset, String.length(value) - offset)
    | [patch, ...patches] =>
      let patch_pre = String.sub(value, offset, patch.offset_start - offset);
      patch_pre
      ++ patch.patch(ctx)
      ++ print(patch.offset_end, value, patches);
    };

  print(0, w.value, patches);
};

let make_patcher = workspace => {
  let order = ref(0);
  let patch_with = (start, offset, f) => {
    let _end = start + offset;

    order := order^ + 1;
    workspace :=
      patch(
        workspace^,
        {
          patch: f,
          offset_start: min(start, _end),
          offset_end: max(start, _end),
          order: order^,
        },
      );
  };

  let patch = (start, offset, s) => patch_with(start, offset, _ => s);
  let remove = (start, offset) => patch(start, offset, "");
  let patch_loc_with = (loc: Loc.t) =>
    patch_with(loc.start.offset, loc._end.offset - loc.start.offset);

  let patch_loc = (loc: Loc.t) =>
    patch(loc.start.offset, loc._end.offset - loc.start.offset);

  let remove_loc = (loc: Loc.t) =>
    remove(loc.start.offset, loc._end.offset - loc.start.offset);

  /* TODO: rename this to something more descriptive */
  let sub = (start, len) => String.sub(workspace^.value, start, len);
  let sub_loc = (loc: Loc.t) =>
    sub(loc.start.offset, loc._end.offset - loc.start.offset);
  {
    patch_with,
    patch,
    remove,
    patch_loc_with,
    patch_loc,
    remove_loc,
    sub,
    sub_loc,
  };
};
