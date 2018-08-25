let () =
  Cmdliner.(Term.exit @@ Fastpack.Commands.(Term.eval_choice(default, all)));
