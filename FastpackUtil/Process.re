type t = {
  cmd: string,
  process: Lwt_process.process_none,
  chIn: Lwt_io.channel(Lwt_io.input),
  chOut: Lwt_io.channel(Lwt_io.output),
};

exception NotRunning(string);

let start = cmd => {
  let (fp_in, process_out) = Unix.pipe();
  let (process_in, fp_out) = Unix.pipe();
  let chIn = Lwt_io.of_unix_fd(~mode=Lwt_io.Input, fp_in);
  let chOut = Lwt_io.of_unix_fd(~mode=Lwt_io.Output, fp_out);
  let process =
    Lwt_process.(
      open_process_none(
        ~env=Unix.environment(),
        ~stdin=`FD_move(process_in),
        ~stdout=`FD_move(process_out),
        ~stderr=`Dev_null,
        shell(cmd),
      )
    );
  {cmd, process, chIn, chOut};
};

let finalize = ({process, _}: t) => {
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

let writeAndReadValue = (value, process) =>
  Lwt_io.atomic(
    chOut =>
      Lwt_io.atomic(
        chIn => {
          let%lwt () = Lwt_io.write_value(chOut, value);
          let%lwt output = Lwt_io.read_value(chIn);
          Lwt.return(output);
        },
        process.chIn,
      ),
    process.chOut,
  );
