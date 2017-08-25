let transpile () =
  let scope = FastpackTranspiler.Util.make_scope () in
  FastpackTranspiler.Main.transpile_source scope

let print source =
  let parse_options = Some Parser_env.({
      esproposal_class_instance_fields = true;
      esproposal_class_static_fields = true;
      esproposal_decorators = true;
      esproposal_export_star_as = true;
      types = true;
      use_strict = false;
    }) in
  let (program, _errors) = Parser_flow.program source ~parse_options in
  let result = Fastpack.Printer.print program in
  result

let tests = [
  ("object-spread-and-rest-operators.js", transpile ());
  ("strip-flow.js", transpile ());
  ("fastpack-printer.js", print);
  ("transpile-react-jsx.js", FastpackTranspiler.transpile_source [FastpackTranspiler.ReactJSX.transpile]);
  (* ("current.js", print); *)
]

let () =
  let (>>=) = Lwt.(>>=) in

  let open Cmdliner in

  let print s = Lwt_io.write Lwt_io.stderr (s ^ "\n") in

  let test_all path train =

    let get_contents name =
      try%lwt
        Lwt_io.(with_file ~mode:Input (path ^ "/" ^ name) read)
        >>= Lwt.return_some
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
      | "y" -> write_file (path ^ "/" ^ filename) data >> Lwt.return_some true
      | "n" -> Lwt.return_some false
      | _ -> Lwt.return_none
    in

    let show_diff name actual =
      let temp_file = Filename.temp_file "" ".result.js" in
      let _ = write_file temp_file actual in
      let cmd = "diff " ^ (path ^ "/" ^ name) ^ " " ^ temp_file in
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

    let test_one f actual expect_fname =
      let%lwt some_expected = get_contents expect_fname in
      match some_expected with
      | Some expected -> (
          let result = f actual in
          match result = expected with
          | true -> Lwt.return_some true
          | false -> show_diff expect_fname result >> Lwt.return_some false)
      | None -> Lwt.return_some false
    in

    let train_one f actual expect_fname =
      let%lwt some_expected = get_contents expect_fname in
      let result = f actual in
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

    let test_or_train_one title f actual expect_fname =
      let _ = Lwt_main.run (print @@ title ^ "\n-------------------") in
      let run = if train then train_one else test_one in
      run f actual expect_fname
    in

    let run_one (fname, f) =
      let%lwt actual = get_contents fname in
      let expect_fname = "expected/" ^ fname in
      match actual with
      | Some c -> test_or_train_one fname f c expect_fname
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

  Term.exit @@ Term.eval (run_t, info)
