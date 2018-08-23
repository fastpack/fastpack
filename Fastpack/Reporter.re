type report =
  | JSON
  | Text;

type file = {
  name: string,
  size: int,
};

module Text = {
  let report_ok =
      (
        ~message=None,
        ~start_time: float,
        ~ctx: Context.t,
        ~files: list(file),
      ) => {
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

  let report_error = (~ctx: Context.t, ~error: Error.reason) => {
    let error_msg = Context.string_of_error(ctx, error);
    Lwt_io.write(Lwt_io.stderr, error_msg);
  };
};

module JSON = {
  let report_ok =
      (
        ~message=None,
        ~start_time: float,
        ~ctx: Context.t,
        ~files: list(file),
      ) => {
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

  let report_error = (~ctx: Context.t, ~error: Error.reason) =>
    Yojson.Basic.(
      `Assoc([("error", `String(Context.string_of_error(ctx, error)))])
      |> to_string(~std=true)
      |> (s => s ++ "\n")
      |> Lwt_io.write(Lwt_io.stderr)
    );
};

type t = {
  report_ok:
    (
      ~message: option(string)=?,
      ~start_time: float,
      ~ctx: Context.t,
      ~files: list(file)
    ) =>
    Lwt.t(unit),
  report_error: (~ctx: Context.t, ~error: Error.reason) => Lwt.t(unit),
};

let make = (report: report) =>
  switch (report) {
  | JSON => JSON.{report_ok, report_error}
  | Text => Text.{report_ok, report_error}
  };
