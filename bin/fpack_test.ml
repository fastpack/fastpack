
type test = string * string * (string -> string -> string)
type t = Test of test
       | Skip of test
       | Only of test

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

let pack ~mode ~target ~preprocessor pack_f entry_filename _ =
  let pack' () =
    let bytes = Lwt_bytes.create 50000000 in
    let ch = Lwt_io.of_bytes ~mode:Lwt_io.Output bytes in
    let%lwt cache = Fastpack.Cache.create None in
    let%lwt _ =
      Fastpack.pack
        ~pack_f
        ~cache
        ~mode
        ~target
        ~preprocessor
        ~entry_filename
        ~package_dir:(Filename.dirname entry_filename)
        ch
    in
  ch
    |> Lwt_io.position
    |> Int64.to_int
    |> Lwt_bytes.extract bytes 0
    |> Lwt_bytes.to_string
    |> Lwt.return
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
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.RegularPacker.pack

let pack_regular_dev =
  pack
    ~mode:Fastpack.Mode.Development
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.RegularPacker.pack

let pack_flat_prod =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.empty
    (Fastpack.FlatPacker.pack)

let pack_flat_dev =
  pack
    ~mode:Fastpack.Mode.Development
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.empty
    (Fastpack.FlatPacker.pack)

let pack_regular_cjs =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.CommonJS
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.RegularPacker.pack

let pack_regular_esm =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.ESM
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.RegularPacker.pack

let pack_flat_esm =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.ESM
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.FlatPacker.pack

let pack_flat_cjs =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.CommonJS
    ~preprocessor:Fastpack.Preprocessor.empty
    Fastpack.FlatPacker.pack

let pack_transpile_regular_dev =
  pack
    ~mode:Fastpack.Mode.Development
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.transpile_all
    Fastpack.RegularPacker.pack

let pack_transpile_flat_prod =
  pack
    ~mode:Fastpack.Mode.Production
    ~target:Fastpack.Target.Application
    ~preprocessor:Fastpack.Preprocessor.transpile_all
    Fastpack.FlatPacker.pack

let tests = [
  Test ("transpile-object-spread.js", "", transpile);
  Test ("transpile-class.js", "", transpile);
  Test ("transpile-react-jsx.js", "", transpile);
  Test ("transpile-strip-flow.js", "", transpile);
  Test ("print.js", "", print ~with_scope:false);
  Test ("print-with-scope.js", "", print ~with_scope:true);
  Test ("pack/index.js", "pack.js", pack_regular_prod);
  Test ("pack_flat/index.js", "pack_flat.js", pack_flat_prod);
  Test ("pack_flat_collisions/index.js", "pack_flat_collisions.js", pack_flat_prod);
  Test ("pack_mode/index.js", "pack_regular_prod.js", pack_regular_prod);
  Test ("pack_mode/index.js", "pack_regular_dev.js", pack_regular_dev);
  Test ("pack_all_static/index.js", "pack_flat_all_static.js", pack_flat_prod);
  Test ("pack_all_static/index.js", "pack_regular_all_static.js", pack_regular_prod);
  Test ("pack_mode/index.js", "pack_flat_prod.js", pack_flat_prod);
  Test ("pack_mode/index.js", "pack_flat_dev.js", pack_flat_dev);
  Test ("pack-target/index.js", "pack-regular-cjs.js", pack_regular_cjs);
  Test ("pack-target/index.js", "error-pack-regular-esm.txt", pack_regular_esm);
  Test ("pack-target/index.js", "pack-flat-esm.js", pack_flat_esm);
  Test ("pack-target/index.js", "pack-flat-cjs.js", pack_flat_cjs);
  Test ("pack-utf8/index.js", "pack-flat-utf8.js", pack_flat_dev);
  Test ("pack-utf8/index.js", "pack-regular-utf8.js", pack_regular_prod);
  Test (
    "error-cannot-rename-module-binding/index.js",
    "error-cannot-rename-module-binding.txt",
    pack_regular_prod
  );
  Test (
    "error-parse/index.js",
    "error-parse.txt",
    pack_regular_prod
  );
  Test (
    "error-cannot-resolve-modules/index.js",
    "error-cannot-resolve-modules.txt",
    pack_regular_prod
  );
  Test (
    "error-cannot-leave-package-dir/index.js",
    "error-cannot-leave-package-dir.txt",
    pack_regular_prod
  );
  Test (
    "error-dependency-cycle/index.js",
    "error-dependency-cycle.txt",
    pack_flat_prod
  );
  Skip (
    "error-cannot-find-exported-name/index.js",
    "error-cannot-find-exported-name.txt",
    pack_flat_prod
  );
  Test (
    "error-scope-naming-collision/index.js",
    "error-scope-naming-collision.txt",
    pack_flat_prod
  );
  Test (
    "error-scope-previously-undefined-export/index.js",
    "error-scope-previously-undefined-export.txt",
    pack_flat_prod
  );
  Test ("pack-flat-reexport/index.js", "pack-flat-reexport.js", pack_flat_prod);
  Test (
    "pack-builtins/index.js",
    "pack-builtins-regular-dev.js",
    pack_transpile_regular_dev
  );
  Test (
    "pack-builtins/index.js",
    "pack-builtins-flat-prod.js",
    pack_transpile_flat_prod
  );
  (* ("current.js", "", transpile); *)
]

let () =
  let (>>=) = Lwt.(>>=) in

  let open Cmdliner in

  let print s = Lwt_io.write Lwt_io.stderr (s ^ "\n") in

  let test_all path train tests =

    let get_contents name =
      try%lwt
        Lwt_io.(with_file ~mode:Input name read) >>= Lwt.return_some
      with Unix.Unix_error _ ->
        let%lwt () = print ("Error, while reading: " ^ name) in
        Lwt.return_none
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
      | "y" -> let%lwt () = write_file filename data in Lwt.return_some true
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
      let%lwt () = print (message ^ " [y(yes)/n(no)/<any key>(halt)]? ") in
      Lwt_io.(read_line stdin)
      >>= save_or_reject filename data
    in

    let test_one f content actual_fname expect_fname =
      let%lwt some_expected = get_contents expect_fname in
      match some_expected with
      | Some expected ->
        begin
          let result = f actual_fname content in
          match result = expected with
          | true ->
            Lwt.return_some true
          | false ->
            let%lwt () = show_diff expect_fname result in
            Lwt.return_some false
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
        else
          let%lwt () = show_diff expect_fname result in
          save_data "Replace old expectation" expect_fname result
      | None ->
        let%lwt () = print "New output:" in
        let%lwt () = print result in
        save_data "Save new output" expect_fname result
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
      let skipped, rest =
        List.partition_map
          (fun test ->
             match test with
             | Skip _ -> `Left test
             | _ -> `Right test
          )
          tests
      in
      let only, rest =
        List.partition_map
          (fun test ->
             match test with
             | Only test -> `Left test
             | Test test -> `Right test
             | Skip _ ->
               failwith "Internal Error: skipped tests should be filtered out."
          )
          rest
      in
      let rest = if List.length only > 0 then only else rest in
      let total = List.length rest in
      let (ok, message) =
        match test_all path train rest with
        | Some 0 ->
          (true, Printf.sprintf "OK. %d passed." total)
        | Some n ->
          (false,  Printf.sprintf "FAIL. %d failed of %d total." n total)
        | None   -> (false,  "Halted.")
      in(
        Lwt_main.run (
          print
          @@ "\n" ^ message
             ^ (if List.length skipped > 0
                then Printf.sprintf " %d skipped." @@ List.length skipped
                else "")
             ^ (if List.length only > 0
                then " ONLY MODE, consider running all tests."
                else "")
        );
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
