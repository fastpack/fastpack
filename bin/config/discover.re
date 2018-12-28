module C = Configurator.V1;

let () =
  C.main(~name="link_flags.sexp", c => {
    let flags =
      switch (C.ocaml_config_var(c, "system")) {
      | Some("linux") => ["-ccopt", "-static"]
      | Some(_)
      | None => ["-ccopt", "-L/usr/lib"]
      };

    C.Flags.write_sexp("link_flags.sexp", flags);
  });
