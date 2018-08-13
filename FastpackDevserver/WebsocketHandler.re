module WServer = Websocket_cohttp_lwt;

module ByConn =
  Map.Make({
    type t = Cohttp.Connection.t;
    let compare = Cohttp.Connection.compare;
  });

type conn = {
  ready: bool,
  frames_out_fn: option(Websocket_cohttp_lwt.Frame.t) => unit,
};

type handler =
  (
    (Conduit_lwt_unix.flow, Cohttp.Connection.t),
    Cohttp_lwt_unix.Request.t,
    Cohttp_lwt.Body.t
  ) =>
  Lwt.t((Cohttp.Response.t, Cohttp_lwt.Body.t));

let makeHandler = (~debug=false, ()): (string => Lwt.t(unit), handler) => {
  open Lwt;
  let debug_log = (msg: string) =>
    if (debug) {
      print_endline(msg);
    } else {
      ();
    };
  let _debug_log_lwt = (msg: string) =>
    if (debug) {
      Lwt_io.eprint(msg);
    } else {
      Lwt.return();
    };
  let conn_update_handlers = Lwt_mvar.create(ByConn.empty);
  (
    message =>
      Lwt_mvar.take(conn_update_handlers)
      >>= (
        handlers =>
          Lwt_mvar.put(conn_update_handlers, handlers)
          >>= (
            () =>
              Lwt.return(
                handlers
                |> ByConn.iter((c, handler) => {
                     debug_log(
                       Printf.sprintf(
                         "Sending message %s to %s\n%!",
                         message,
                         Cohttp.Connection.to_string(c),
                       ),
                     );
                     if (handler.ready) {
                       handler.frames_out_fn @@
                       Some(WServer.Frame.create(~content=message, ()));
                     } else {
                       ();
                     };
                   }),
              )
          )
      ),
    (conn, req, body) =>
      Lwt.(
        Cohttp_lwt.Body.drain_body(body)
        >>= (
          () =>
            WServer.upgrade_connection(req, fst(conn), fr =>
              WServer.(
                switch (fr.opcode) {
                | Frame.Opcode.Close =>
                  Lwt.async(() =>
                    Lwt_mvar.take(conn_update_handlers)
                    >>= (
                      handlers => {
                        let updated = ByConn.remove(snd(conn), handlers);
                        Lwt_mvar.put(conn_update_handlers, updated);
                      }
                    )
                  )
                | _ =>
                  debug_log(
                    Printf.sprintf("Received message \"%s\"", fr.content),
                  );
                  if (fr.content == "hello") {
                    Lwt.async(() =>
                      Lwt_mvar.take(conn_update_handlers)
                      >>= (
                        handlers => {
                          let m = h =>
                            switch (h) {
                            | Some(c) => Some({...c, ready: true})
                            | _ => None
                            };
                          let updated =
                            ByConn.update(snd(conn), m, handlers);
                          Lwt_mvar.put(conn_update_handlers, updated);
                        }
                      )
                    );
                  } else {
                    ();
                  };
                }
              )
            )
        )
        >>= (
          ((resp, body, frames_out_fn)) => {
            debug_log(
              Printf.sprintf(
                "Adding client %s \n%!",
                snd(conn) |> Cohttp.Connection.to_string,
              ),
            );

            Lwt_mvar.take(conn_update_handlers)
            >>= (
              handlers => {
                let updated =
                  ByConn.add(
                    snd(conn),
                    {ready: false, frames_out_fn},
                    handlers,
                  );
                Lwt_mvar.put(conn_update_handlers, updated)
                >>= (
                  () =>
                    Lwt.wrap1(frames_out_fn) @@
                    Some(WServer.Frame.create(~content="hello", ()))
                    >>= (
                      () => Lwt.return((resp, (body :> Cohttp_lwt.Body.t)))
                    )
                );
              }
            );
          }
        )
      ),
  );
};
