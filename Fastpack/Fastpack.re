module Version = Version;
module Error = Error;
module Cache = Cache;
module Mode = Mode;
module Target = Target;
module Context = Context;
module Module = Module;
module Resolver = Resolver;
module Preprocessor = Preprocessor;
module Reporter = Reporter;
module Watcher = Watcher;
module CommonOptions = CommonOptions;
module Commands = Commands

exception PackError = Context.PackError;
exception ExitError = Context.ExitError;
exception ExitOK = Context.ExitOK;

let pack_main = (options, start_time) =>
  Lwt_main.run(
    {
      let%lwt {Packer.pack, finalize} = Packer.make(options);

      Lwt.finalize(
        () =>
          switch%lwt (
            pack(
              ~graph=None,
              ~current_location=None,
              ~initial=true,
              ~start_time,
            )
          ) {
          | Error(_) => raise(ExitError(""))
          | Ok(ctx) =>
            switch (options.watch) {
            | false => Lwt.return_unit
            | true =>
              switch (options.mode) {
              | Development => Watcher.watch(~ctx, ~pack)
              | _ =>
                /* TODO: noop warning*/
                Lwt.return_unit
              }
            }
          },
        finalize,
      );
    },
  );
