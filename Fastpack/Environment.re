let executable = ref(Sys.argv[0]);

let getExecutable = () => executable^;
let setExecutable = newExecutable => executable := newExecutable;

let getCPUCount = () =>
  try (
    switch (Sys.os_type) {
    | "Win32" => int_of_string(Sys.getenv("NUMBER_OF_PROCESSORS"))
    | _ =>
      let i = Unix.open_process_in("getconf _NPROCESSORS_ONLN");
      let close = () => ignore(Unix.close_process_in(i));
      try (
        Scanf.bscanf(
          Scanf.Scanning.from_channel(i),
          "%d",
          n => {
            close();
            n;
          },
        )
      ) {
      | e =>
        close();
        raise(e);
      };
    }
  ) {
  | Not_found
  | Sys_error(_)
  | Failure(_)
  | Scanf.Scan_failure(_)
  | End_of_file
  | Unix.Unix_error(_, _, _) => 1
  };
