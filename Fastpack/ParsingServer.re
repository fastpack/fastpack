module Ast = FlowParser.Ast;
module Loc = FlowParser.Loc;

type input = {
  location: Module.location,
  source: option(string),
};

type output =
  | ParsedOK(string, Ast.program(Loc.t), artifacts)
  | ParseError(list((Loc.t, FlowParser.Parse_error.t)))
  | PreprocessorError(string)
  | UnhandledCondition(string)
  | Traceback(string)
and artifacts = {
  files: list(string),
  build_dependencies: list(string),
};

let start = (~project_root, ~current_dir, ~output_dir) => {
  let%lwt {Preprocessor.process, finalize, _} =
    Preprocessor.make(~configs=[], ~project_root, ~current_dir, ~output_dir);
  let rec parse = () => {
    let%lwt input: Lwt.t(input) = Lwt_io.read_value(Lwt_io.stdin);
    let {location, source} = input;
    let%lwt output =
      Lwt.catch(
        () => {
          let%lwt (source, build_dependencies, files) =
            process(location, source);
          let (program, _) = FastpackUtil.Parser.parse_source(source);
          Lwt.return(
            ParsedOK(source, program, {build_dependencies, files}),
          );
        },
        fun
        | FlowParser.Parse_error.Error(args) => Lwt.return(ParseError(args))
        | Preprocessor.Error(message) =>
          Lwt.return(PreprocessorError(message))
        | FastpackUtil.Error.UnhandledCondition(message) =>
          Lwt.return(UnhandledCondition(message))
        | exn =>
          Traceback(Printexc.(to_string(exn) ++ "\n" ++ get_backtrace()))
          |> Lwt.return,
      );
    let%lwt () = Lwt_io.write_value(Lwt_io.stdout, output);
    parse();
  };

  Lwt.finalize(() => parse(), finalize);
};

module Reader = {
  type t = {
    read:
      (~location: Module.location, ~source: option(string)) => Lwt.t(output),
    finalize: unit => Lwt.t(unit),
  };

  let ps_project_root = ref("");
  let ps_output_dir = ref("");
  let pool =
    Lwt_pool.create(
      3,
      ~dispose=
        ((p, _, _)) => {
          p#terminate;
          p#close |> ignore |> Lwt.return;
        },
      () => {
        Logs.debug(x => x("reader created"));
        module FS = FastpackUtil.FS;
        let fpack_binary_path =
          /* TODO: handle on Windows? */
          (
            switch (Sys.argv[0].[0]) {
            | '/'
            | '.' => Sys.argv[0]
            | _ => FileUtil.which(Sys.argv[0])
            }
          )
          |> FileUtil.readlink
          |> FS.abs_path(Unix.getcwd());

        let cmd =
          Printf.sprintf(
            "%s parsing-server --project-root='%s' --output='%s'",
            fpack_binary_path,
            ps_project_root^,
            ps_output_dir^,
          );
        FS.open_process(cmd);
      },
    );

  let make = (~project_root, ~output_dir) => {
    ps_project_root := project_root;
    ps_output_dir := output_dir;

    let read = (~location, ~source) =>
      Lwt_pool.use(
        pool,
        ((_, fp_in_ch, fp_out_ch)) => {
          let%lwt () = Lwt_io.write_value(fp_out_ch, {location, source});
          let%lwt output: Lwt.t(output) = Lwt_io.read_value(fp_in_ch);
          Lwt.return(output);
        },
      );

    Lwt.return({read, finalize: () => Lwt_pool.clear(pool)});
  };
};
