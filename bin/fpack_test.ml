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

let pack pack_f entry_filename _ =
  let pack' () =
    let bytes = Lwt_bytes.create 20000000 in
    let ch = Lwt_io.of_bytes ~mode:Lwt_io.Output bytes in
    Fastpack.pack
      ~pack_f
      ~mode:Fastpack.Mode.Production
      ~transpile_f:(fun _ _ p -> p)
      ~entry_filename
      ~package_dir:(Filename.dirname entry_filename)
      ch
    >> Lwt.return
       @@ Lwt_bytes.to_string
       @@ Lwt_bytes.extract bytes 0
       @@ Int64.to_int
       @@ Lwt_io.position ch
  in Lwt_main.run (pack' ())

let pack_regular =
  pack (Fastpack.RegularPacker.pack ~with_runtime:false)

let pack_flat =
  pack (Fastpack.FlatPacker.pack)

let pack_stdout entry_filename _ =
  let pack' () =
    Fastpack.pack
      ~pack_f:(Fastpack.FlatPacker.pack)
      ~mode:Fastpack.Mode.Production
      ~transpile_f:(fun _ _ p -> p)
      ~entry_filename
      ~package_dir:(Filename.dirname entry_filename)
      Lwt_io.stdout
  in Lwt_main.run (pack' ()); ""

let tests = [
  ("transpile-object-spread.js", "", transpile);
  ("transpile-class.js", "", transpile);
  ("transpile-react-jsx.js", "", transpile);
  ("transpile-strip-flow.js", "", transpile);
  ("print.js", "", print ~with_scope:false);
  ("print-with-scope.js", "", print ~with_scope:true);
  ("pack/index.js", "pack.js", pack_regular);
  ("pack_flat/index.js", "pack_flat.js", pack_flat);
  ("pack_flat_collisions/index.js", "pack_flat_collisions.js", pack_flat);
  (* ("current.js", "", print ~with_scope:false); *)
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
      let cmd = "colordiff " ^ name ^ " " ^ temp_file in
      let%lwt output = Lwt_process.(pread @@ shell cmd) in
      Lwt.finalize
        (fun () -> print output)
        (fun () -> Lwt.return_unit)
        (* (fun () -> Lwt_unix.unlink temp_file) *)
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
      let actual_fname = path ^ "/" ^ fname in
      let expect_fname =
        if expect_fname = ""
        then path ^ "/expected/" ^ fname
        else path ^ "/expected/" ^ expect_fname
      in
      let%lwt actual = get_contents actual_fname in
      match actual with
      | Some c -> test_or_train_one fname f c actual_fname expect_fname
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

    let test_all_t path train =
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
    Term.(const test_all_t $ path $ train)
  in

  let info =
    let doc =
      "Test Fpack"
    in
    Term.info "fpack_test" ~version:"preview" ~doc ~exits:Term.default_exits
  in

  Logs.set_level (Some Logs.Debug);
  Logs.set_reporter (Logs_fmt.reporter ());
  Term.exit @@ Term.eval (run_t, info)
