let () =
  let echo x = x in
  let tests = [
      ("echo.js", echo)
    ; ("echo2.js", echo)
  ] in

  let (>>=) = Lwt.(>>=) in

  let open Cmdliner in


  let print s = Lwt_io.write Lwt_io.stderr (s ^ "\n") in

  let test_all path train =

    let get_contents name =
      try%lwt
        Lwt_io.with_file ~mode:Lwt_io.Input (path ^ "/" ^ name) Lwt_io.read
        >>= Lwt.return_some
      with Unix.Unix_error _ ->
         print ("Error, while reading: " ^ name) >> Lwt.return_none
    in

    let save_or_reject filename data answer =
      match answer with
      | "y" ->
        Lwt_io.with_file
          ~mode:Lwt_io.Output
          ~perm:0o640
          ~flags:[Unix.O_CREAT; Unix.O_TRUNC; Unix.O_RDWR]
          (path ^ "/" ^ filename)
          (fun ch -> Lwt_io.write ch data)
        >> Lwt.return_some true
      | "n" -> Lwt.return_some false
      | _ -> Lwt.return_none
    in


    let show_diff name actual =
      let temp_file = Filename.temp_file "" ".result.js" in
      let _ =
        Lwt_io.with_file
          ~mode:Lwt_io.Output
          ~perm:0o640
          ~flags:[Unix.O_CREAT; Unix.O_TRUNC; Unix.O_RDWR]
          temp_file
          (fun ch -> Lwt_io.write ch actual)
      in
      let cmd = "diff " ^ (path ^ "/" ^ name) ^ " " ^ temp_file in
      let%lwt output = Lwt_process.pread (Lwt_process.shell cmd) in
      print output
    in

    let save_data message filename data =
      print (message ^ " [y(yes)/n(no)/<any key>(halt)]? ")
      >> Lwt_io.read_line Lwt_io.stdin
      >>= save_or_reject filename data
    in

    let test_one (fname, f) =
      (Lwt_main.run (print @@ fname ^ "\n-------------------");
      let expect_fname = "expected/" ^ fname in
      let%lwt contents = get_contents fname in
      let%lwt expect = get_contents expect_fname in
       match (contents, expect, train) with
       | (Some c, Some e, false) -> Lwt.return_some (f c = e)
       | (Some c, Some e, true) ->
         let result = f c in
         if result = e
           then Lwt.return_some true
           else show_diff expect_fname result
                >> save_data "Replace old expectation" expect_fname result
       | (Some c, None, true) ->
         let result = f c in
         print "New output:"
         >> print result
         >> save_data "Save new output" expect_fname result
       | _ -> Lwt.return_some false
      )
    in

    let gather_result result test =
      match result with
      | None -> None (* short-circuit if previous test is halted *)
      | Some n ->
        match Lwt_main.run (test_one test) with
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
