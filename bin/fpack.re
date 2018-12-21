Lwt_io.set_default_buffer_size(8000000);
let () =
  Cmdliner.(Term.exit @@ Fastpack.Commands.(Term.eval_choice(default, all())));
