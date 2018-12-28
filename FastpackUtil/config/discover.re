module C = Configurator.V1;

let () =
  C.main(~name="c_link_flags.sexp", c => {
    let flags =
      switch (C.ocaml_config_var(c, "os_type")) {
      | Some("Win32") => ["-D_WIN32"]
      | Some(_)
      | None => []
      };

    C.Flags.write_sexp("c_link_flags.sexp", flags);
  });
