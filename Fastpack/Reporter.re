type file = {
  name: string,
  size: int,
};
type onOk =
  (
    ~message: option(string),
    ~start_time: float,
    ~files: list(file),
    Context.t
  ) =>
  Lwt.t(unit);
type onError = (~error: Error.reason, Context.t) => Lwt.t(unit);

type t = {
  onOk,
  onError,
};

let make = (onOk: onOk, onError: onError, ()) => {
  onOk,
  onError,
};

let reportOk = (~message, ~start_time, ~files, ~ctx, reporter) =>
  reporter.onOk(~message, ~start_time, ~files, ctx)

let reportError = (~error, ~ctx, reporter) =>
  reporter.onError(~error, ctx)

module Text = {
  let onOk =
      (~message, ~start_time: float, ~files: list(file), ctx: Context.t) => {
    /* TODO: fix next line when we report multiple files */
    let {size, _} = List.hd(files);
    let pretty_size =
      Printf.(
        if (size >= 1048576) {
          sprintf("%.2fMb", float_of_int(size) /. 1048576.0);
        } else if (size >= 1024) {
          sprintf(
            "%dKb",
            float_of_int(size) /. 1024.0 +. 0.5 |> floor |> int_of_float,
          );
        } else {
          sprintf("%db", size);
        }
      );

    Printf.sprintf(
      "Packed in %.3fs. Bundle: %s. Modules: %d. %s\n",
      Unix.gettimeofday() -. start_time,
      pretty_size,
      DependencyGraph.length(ctx.graph),
      CCOpt.get_or(~default="", message),
    )
    |> Lwt_io.write(Lwt_io.stdout);
  };

  let onError = (~error: Error.reason, ctx: Context.t) => {
    let error_msg = Context.stringOfError(ctx, error);
    Lwt_io.write(Lwt_io.stderr, error_msg);
  };

  let make = make(onOk, onError);
};

module JSON = {
  let onOk =
      (~message, ~start_time: float, ~files: list(file), ctx: Context.t) => {
    open Yojson.Basic;
    let files =
      files
      |> List.map(({name, size}) =>
           `Assoc([("name", `String(name)), ("size", `Int(size))])
         );

    let modules =
      ctx.graph
      |> DependencyGraph.modules
      |> Sequence.map(((location, _)) =>
           `String(Module.location_to_string(location))
         )
      |> Sequence.sort(~cmp=Pervasives.compare)
      |> Sequence.to_list;

    let message =
      switch (message) {
      | None => `Null
      | Some(message) => `String(message)
      };

    `Assoc([
      ("time", `Float(Unix.gettimeofday() -. start_time)),
      ("files", `List(files)),
      ("modules", `List(modules)),
      ("message", message),
    ])
    |> to_string(~std=true)
    |> (s => s ++ "\n")
    |> Lwt_io.write(Lwt_io.stdout);
  };

  let onError = (~error: Error.reason, ctx: Context.t) =>
    Yojson.Basic.(
      `Assoc([("error", `String(Context.stringOfError(ctx, error)))])
      |> to_string(~std=true)
      |> (s => s ++ "\n")
      |> Lwt_io.write(Lwt_io.stderr)
    );

  let make = make(onOk, onError);
};
