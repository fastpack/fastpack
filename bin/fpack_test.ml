let print ?(with_scope=false) _ source =
  let program, _ = FastpackUtil.Parser.parse_source source in
  let result = FastpackUtil.Printer.print ~with_scope program in
  result

let transpile _ =
  FastpackTranspiler.transpile_source [
    FastpackTranspiler.StripFlow.transpile;
    FastpackTranspiler.ReactJSX.transpile;
    FastpackTranspiler.Class.transpile;
    FastpackTranspiler.ObjectSpread.transpile;
  ]

let pack ~mode ~target pack_f entry_filename _ =
  let pack' () =
    let bytes = Lwt_bytes.create 20000000 in
    let ch = Lwt_io.of_bytes ~mode:Lwt_io.Output bytes in
    Fastpack.pack
      ~pack_f
      ~mode
      ~target
      ~transpile_f:(fun _ _ p -> p)
      ~entry_filename
      ~package_dir:(Filename.dirname entry_filename)
      ch
    >> Lwt.return
       @@ Lwt_bytes.to_string
       @@ Lwt_bytes.extract bytes 0
       @@ Int64.to_int
       @@ Lwt_io.position ch
  in
  try
    Lwt_main.run (pack' ())
  with
  | Fastpack.PackError (ctx, error) ->
    let cwd = Unix.getcwd () in
    Fastpack.string_of_error ctx error
    |> String.replace ~sub:cwd ~by:"/..."

let pack_regular_prod =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.Application
    Fastpack.RegularPacker.pack

let pack_regular_dev =
  pack
    ~mode:Fastpack.Mode.Development
    ~target:Fastpack.Target.Application
    Fastpack.RegularPacker.pack

let pack_flat_prod =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.Application
    (Fastpack.FlatPacker.pack)

let pack_flat_dev =
  pack
    ~mode:Fastpack.Mode.Development
    ~target:Fastpack.Target.Application
    (Fastpack.FlatPacker.pack)

let pack_regular_cjs =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.CommonJS
    Fastpack.RegularPacker.pack

let pack_regular_es6 =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.EcmaScript6
    Fastpack.RegularPacker.pack

let pack_flat_es6 =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.EcmaScript6
    Fastpack.FlatPacker.pack

let pack_flat_cjs =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.CommonJS
    Fastpack.FlatPacker.pack

let tests = [
  ("transpile-object-spread.js", "", transpile);
  ("transpile-class.js", "", transpile);
  ("transpile-react-jsx.js", "", transpile);
  ("transpile-strip-flow.js", "", transpile);
  ("print.js", "", print ~with_scope:false);
  ("print-with-scope.js", "", print ~with_scope:true);
  ("pack/index.js", "pack.js", pack_regular_prod);
  ("pack_flat/index.js", "pack_flat.js", pack_flat_prod);
  ("pack_flat_collisions/index.js", "pack_flat_collisions.js", pack_flat_prod);
  ("pack_mode/index.js", "pack_regular_prod.js", pack_regular_prod);
  ("pack_mode/index.js", "pack_regular_dev.js", pack_regular_dev);
  ("pack_all_static/index.js", "pack_flat_all_static.js", pack_flat_prod);
  ("pack_all_static/index.js", "pack_regular_all_static.js", pack_regular_prod);
  ("pack_mode/index.js", "pack_flat_prod.js", pack_flat_prod);
  ("pack_mode/index.js", "pack_flat_dev.js", pack_flat_dev);
  ("pack-target/index.js", "pack-regular-cjs.js", pack_regular_cjs);
  ("pack-target/index.js", "error-pack-regular-es6.txt", pack_regular_es6);
  ("pack-target/index.js", "pack-flat-es6.js", pack_flat_es6);
  ("pack-target/index.js", "pack-flat-cjs.js", pack_flat_cjs);
  ("pack-utf8/index.js", "pack-flat-utf8.js", pack_flat_dev);
  ("pack-utf8/index.js", "pack-regular-utf8.js", pack_regular_prod);
  (
    "error-cannot-rename-module-binding/index.js",
    "error-cannot-rename-module-binding.txt",
    pack_regular_prod
  );
  (
    "error-parse/index.js",
    "error-parse.txt",
    pack_regular_prod
  );
  (
    "error-cannot-resolve-modules/index.js",
    "error-cannot-resolve-modules.txt",
    pack_regular_prod
  );
  (
    "error-cannot-leave-package-dir/index.js",
    "error-cannot-leave-package-dir.txt",
    pack_regular_prod
  );
  (
    "error-dependency-cycle/index.js",
    "error-dependency-cycle.txt",
    pack_flat_prod
  );
  (
    "error-cannot-find-exported-name/index.js",
    "error-cannot-find-exported-name.txt",
    pack_flat_prod
  );
  (
    "error-scope-naming-collision/index.js",
    "error-scope-naming-collision.txt",
    pack_flat_prod
  );
  (
    "error-scope-previously-undefined-export/index.js",
    "error-scope-previously-undefined-export.txt",
    pack_flat_prod
  );
  (* ("current.js", "", transpile); *)
]

let () =
  let (>>=) = Lwt.(>>=) in

  let open Cmdliner in

  let print s = Lwt_io.write Lwt_io.stderr (s ^ "\n") in

  let test_all path train =

    let get_contents name =
      try%lwt
        Lwt_io.(with_file ~mode:Input name read) >>= Lwt.return_some
      with Unix.Unix_error _ ->
        print ("Error, while reading: " ^ name) >> Lwt.return_none
    in

    let write_file name data =
      Lwt_io.(with_file
                ~mode:Output
                ~perm:0o640
                ~flags:Unix.[O_CREAT; O_TRUNC; O_RDWR]
                name
                (fun ch -> write ch data))
    in

    let save_or_reject filename data answer =
      match answer with
      | "y" -> write_file filename data >> Lwt.return_some true
      | "n" -> Lwt.return_some false
      | _ -> Lwt.return_none
    in

    let show_diff name actual =
      let temp_file = Filename.temp_file "" ".result.js" in
      let _ = write_file temp_file actual in
      let cmd = "git diff --color " ^ name ^ " " ^ temp_file in
      let%lwt output = Lwt_process.(pread @@ shell cmd) in
      Lwt.finalize
        (fun () -> print output)
        (fun () -> Lwt_unix.unlink temp_file)
    in

    let save_data message filename data =
      print (message ^ " [y(yes)/n(no)/<any key>(halt)]? ")
      >> Lwt_io.(read_line stdin)
      >>= save_or_reject filename data
    in

    let test_one f content actual_fname expect_fname =
      let%lwt some_expected = get_contents expect_fname in
      match some_expected with
      | Some expected ->
        begin
          let result = f actual_fname content in
          match result = expected with
          | true -> Lwt.return_some true
          | false -> show_diff expect_fname result >> Lwt.return_some false
        end
      | None -> Lwt.return_some false
    in

    let train_one f content actual_fname expect_fname =
      let%lwt some_expected = get_contents expect_fname in
      let result = f actual_fname content in
      match some_expected with
      | Some expected ->
        if result = expected
        then Lwt.return_some true
        else show_diff expect_fname result
          >> save_data "Replace old expectation" expect_fname result
      | None ->
        print "New output:"
        >> print result
        >> save_data "Save new output" expect_fname result
    in

    let test_or_train_one title f content actual_fname expect_fname =
      let _ = Lwt_main.run (print @@ title ^ "\n-------------------") in
      let run = if train then train_one else test_one in
      run f content actual_fname expect_fname
    in

    let run_one (fname, expect_fname, f) =
      let title = if expect_fname = "" then fname else expect_fname in
      let actual_fname = path ^ "/" ^ fname in
      let expect_fname =
        if expect_fname = ""
        then path ^ "/expected/" ^ fname
        else path ^ "/expected/" ^ expect_fname
      in
      let%lwt actual = get_contents actual_fname in
      match actual with
      | Some c -> test_or_train_one title f c actual_fname expect_fname
      | None -> Lwt.return_some false
    in

    let gather_result result test =
      match result with
      | None -> None (* short-circuit if previous test is halted *)
      | Some n ->
        match Lwt_main.run (run_one test) with
        | Some false -> Some (n + 1)
        | Some true -> Some n
        | None -> None
    in

    List.fold_left gather_result (Some 0) tests
  in

  let run_t =
    let train =
      let doc = "train test runner" in
      Arg.(value & flag & info ["t"; "train"] ~docv:"TRAIN" ~doc)
    in

    let path =
      let doc = "Absolute path to tests." in
      Arg.(required & pos 0 (some dir) None & info [] ~docv:"TEST_PATH" ~doc)
    in

    let debug_t =
      let doc = "Print debug output" in
      Arg.(value & flag & info ["d"; "debug"] ~doc)
    in

    let test_all_t path train debug =
      if debug then begin
        Logs.set_level (Some Logs.Debug);
        Logs.set_reporter (Logs_fmt.reporter ());
      end;
      let total = List.length tests in
      let (ok, message) =
        match test_all path train with
        | Some 0 ->
          (true, Printf.sprintf "OK. %d passed." total)
        | Some n ->
          (false,  Printf.sprintf "FAIL. %d failed of %d total." n total)
        | None   -> (false,  "Halted.")
      in(
        Lwt_main.run (print @@ "\n" ^ message);
        if ok then
          `Ok message
        else
          `Error (false, message)
      )
    in
    Term.(const test_all_t $ path $ train $ debug_t)
  in

  let info =
    let doc =
      "Test Fpack"
    in
    Term.info "fpack_test" ~version:"preview" ~doc ~exits:Term.default_exits
  in

  Term.exit @@ Term.eval (run_t, info)
