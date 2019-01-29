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

let addPid = env => {
  let var = "FASTPACK_PARENT_PID";
  Array.concat([
    CCArray.filter(v => !CCString.mem(~start=0, ~sub=var ++ "=", v), env),
    [|Printf.sprintf("%s=%d", var, pid_of_handle(Unix.getpid()))|],
  ]);
};

let start = cmd => {
  let (fp_in, process_out) = Lwt_unix.pipe();
  let (process_in, fp_out) = Lwt_unix.pipe();
  let chIn = Lwt_io.of_fd(~mode=Lwt_io.Input, fp_in);
  let chOut = Lwt_io.of_fd(~mode=Lwt_io.Output, fp_out);
  let process =
    Lwt_process.(
      open_process_none(
        ~env=addPid(Unix.environment()),
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

let writeAndReadValue = (~msg=?, value, process) => {
  let prefix =
    switch (msg) {
    | Some(s) => s
    | None => "no msg"
    };

  let exit = () => {
    let%lwt () = Lwt_unix.sleep(50.0);
    failwith(prefix);
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
