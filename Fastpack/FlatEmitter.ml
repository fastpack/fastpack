
module MLSet = Module.LocationSet 
module StringSet = Set.Make(String)
module FS = FastpackUtil.FS

let emit_module_files (ctx : Context.t) (m : Module.t) =
  Lwt_list.iter_s
    (fun (filename, content) ->
      let path = FS.abs_path ctx.output_dir filename in
      let%lwt () = FS.makedirs (FilePath.dirname path) in
      Lwt_io.(with_file
                ~mode:Lwt_io.Output
                ~perm:0o640
                ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
                path
                (fun ch -> write ch content)
             )
    )
    m.files

let run (_ctx : Context.t) _output_channel =
  (* let sorted = *)
  (*   try *)
  (*     DependencyGraph.sort ctx.graph entry *)
  (*   with *)
  (*   | DependencyGraph.Cycle filenames -> *)
  (*     raise (PackError (ctx, DependencyCycle filenames)) *)
  (* in *)
  (* let from_eval s = *)
  (*   match Yojson.Safe.from_string ("\"" ^ s ^ "\"") with *)
  (*   | `String s -> s *)
  (*   | _ -> failwith "unexpected module content" *)
  (* in *)
  Lwt.return (StringSet.empty, 0)

let emit (ctx : Context.t) =
  let temp_file =
    Filename.temp_file ~temp_dir:ctx.output_dir ".fpack" ".bundle.js"
  in
  Lwt.finalize
    (fun () ->
      let%lwt emitted_modules, size =
        Lwt_io.with_file
          ~mode:Lwt_io.Output
          ~perm:0o640
          ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
          temp_file
          (run ctx)
      in
      let%lwt () = Lwt_unix.rename temp_file ctx.output_file in
      Lwt.return (emitted_modules, [{Reporter. name = ctx.output_file; size}])
    )
    (fun () ->
       if%lwt Lwt_unix.file_exists temp_file
       then Lwt_unix.unlink temp_file;
    )
