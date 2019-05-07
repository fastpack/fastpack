type t = {
  cmd: string,
  process: Lwt_process.process_none,
  chIn: Lwt_io.channel(Lwt_io.input),
  chOut: Lwt_io.channel(Lwt_io.output),
  descr: list(Unix.file_descr),
};

exception NotRunning(string);
/* exception CannotRead */

external pid_of_handle: int => int = "pid_of_handle";

let addEnvVar = (var, value, env) =>
  Array.concat([
    CCArray.filter(v => !CCString.mem(~start=0, ~sub=var ++ "=", v), env),
    [|Printf.sprintf("%s=%s", var, value)|],
  ]);

let addPid =
  addEnvVar(
    "FASTPACK_PARENT_PID",
    Unix.getpid() |> pid_of_handle |> string_of_int,
  );

let start = (~env=[], cmd) => {
  let (fp_in, process_out) = Lwt_unix.pipe();
  let (process_in, fp_out) = Lwt_unix.pipe();
  let chIn = Lwt_io.of_fd(~mode=Lwt_io.Input, fp_in);
  let chOut = Lwt_io.of_fd(~mode=Lwt_io.Output, fp_out);
  let env =
    env
    |> List.fold_left(
         (env, (var, value)) => addEnvVar(var, value, env),
         Unix.environment(),
       )
    |> addPid;
  let process =
    Lwt_process.(
      open_process_none(
        ~env,
        ~stdin=`FD_move(Lwt_unix.unix_file_descr(process_in)),
        ~stdout=`FD_move(Lwt_unix.unix_file_descr(process_out)),
        ~stderr=`Dev_null,
        ("", cmd),
      )
    );
  {
    cmd: String.concat(" ", Array.to_list(cmd)),
    process,
    chIn,
    chOut,
    descr: [
      Lwt_unix.unix_file_descr(fp_in),
      Lwt_unix.unix_file_descr(fp_out),
    ],
  };
};

let finalize = ({process, descr, _}: t) => {
  List.iter(Unix.close, descr);
  process#terminate;
  process#close |> ignore;
  Lwt.return_unit;
};

let write = (msg, process) =>
  Lwt_io.atomic(ch => Lwt_io.write(ch, msg), process.chOut);

let readLine = process =>
  Lwt_io.atomic(
    ch =>
      switch%lwt (Lwt_io.read_line(ch)) {
      | exception End_of_file => Lwt.fail(NotRunning(process.cmd))
      | line => Lwt.return(line)
      },
    process.chIn,
  );

let writeValue = (value, process) =>
  Lwt_io.write_value(process.chOut, value);

let writeAndReadValue = (~msg=?, value, process) => {
  let msg =
    switch (msg) {
    | Some(s) => s
    | None => "no msg"
    };

  let exit = () => {
    let%lwt () = Lwt_unix.sleep(30.0);
    failwith(msg);
  };

  Lwt.pick([
    {
      let%lwt () = Lwt_io.write_value(process.chOut, value);
      let%lwt output = Lwt_io.read_value(process.chIn);
      Lwt.return(output);
    },
    exit(),
  ]);
};
