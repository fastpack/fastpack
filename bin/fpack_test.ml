let () =
  let echo x = x in
  let tests = [
    ("echo.js", echo)
  ] in

  (* let debug x = Lwt_io.write Lwt_io.stderr (x ^ "\n") in *)

  let open Cmdliner in

  let test_path_env = "FPACK_TEST_PATH" in

  let test_all path tests =

    let test_one (fname, f) =
      let expect_fname = "expected/" ^ fname in
      let%lwt contents =
        try%lwt
          Lwt.bind
            (Lwt_io.with_file ~mode:Lwt_io.Input (path ^ "/" ^ fname) Lwt_io.read)
            Lwt.return_some
        with Unix.Unix_error _ ->
           Lwt_io.write Lwt_io.stderr ("ERROR: " ^ fname ^ " not found \n")
           >> Lwt.return_none
      in
      let%lwt expect =
        try%lwt
          Lwt.bind
            (Lwt_io.with_file ~mode:Lwt_io.Input (path ^ "/" ^ expect_fname) Lwt_io.read)
            Lwt.return_some

        with Unix.Unix_error _ ->
          Lwt_io.write Lwt_io.stderr ("ERROR: " ^ expect_fname ^ " not found \n")
          >> Lwt.return None
      in
      (match (contents, expect) with
       | (Some c, Some e) -> Lwt.return (f c = e)
       | _ -> Lwt.return false
      )
    in

    let total = List.length tests in
    let failed =
      List.length
      @@ List.filter (fun r -> not r)
      @@ List.map (fun t -> Lwt_main.run (test_one t)) tests
    in
    let message =
      (if failed = 0 then
        Printf.sprintf "OK. %d passed.\n" total
       else
        Printf.sprintf "FAIL. %d failed of %d total.\n" failed total
      )
    in Lwt_main.run (Lwt_io.write Lwt_io.stderr message)
  in

  let run_t =
    let run_tests =
      let test_path =
        try
          Some (Sys.getenv test_path_env)
        with
        | Not_found -> None
      in
      (match test_path with
       | None  -> `Error (false, "No \"" ^ test_path_env ^ "\" provided")
       | Some path -> `Ok (test_all path tests))
    in
    Term.(ret @@ const run_tests)
  in

  let info =
    let doc =
      "Test Fpack"
    in
    Term.info "fpack_test" ~version:"preview" ~doc ~exits:Term.default_exits
  in

  Term.exit @@ Term.eval (run_t, info)
