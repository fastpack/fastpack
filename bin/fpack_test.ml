let () =
  let echo x = x in
  let tests = [
    ("echo.js", echo)
  ] in

  let (>>=) = Lwt.(>>=) in

  let open Cmdliner in


  let print s = Lwt_io.write Lwt_io.stderr (s ^ "\n") in

  let test_all path train =
    (Lwt_main.run @@ print @@ "Train mode: " ^ (string_of_bool train));

    let read_file name =
      Lwt_io.with_file ~mode:Lwt_io.Input (path ^ "/" ^ name) Lwt_io.read
    in

    let test_one (fname, f) =
      let expect_fname = "expected/" ^ fname in
      let%lwt contents =
        try%lwt
            read_file fname >>= Lwt.return_some
        with Unix.Unix_error _ ->
           print ("Error, while reading: " ^ fname) >> Lwt.return_none
      in
      let%lwt expect =
        try%lwt
          read_file expect_fname >>= Lwt.return_some
        with Unix.Unix_error _ ->
          print ("Error, while reading: " ^ expect_fname) >> Lwt.return_none
      in
      (match (contents, expect) with
       | (Some c, Some e) -> Lwt.return (f c = e)
       | _ -> Lwt.return false
      )
    in
    List.length
    @@ List.filter (fun r -> not r)
    @@ List.map (fun t -> Lwt_main.run (test_one t)) tests
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
      let failed = test_all path train in
      let message =
        (if failed = 0 then
          Printf.sprintf "OK. %d passed." total
         else
          Printf.sprintf "FAIL. %d failed of %d total." failed total
        )
      in(
        Lwt_main.run (print message);
        if failed = 0 then
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
