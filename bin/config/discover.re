module C = Configurator.V1;

let () =
  C.main(~name="fpack.flags", c => {
    let flags =
      switch (C.ocaml_config_var(c, "system")) {
      | Some("linux") => ["-ccopt", "-static"]
      | Some(_)
      | None => ["-ccopt", "-L/usr/lib"]
      };

    C.Flags.write_sexp("fpack.flags", flags);
  });
