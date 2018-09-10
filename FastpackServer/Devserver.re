let createCallback =
    (~config, ~websocketHandler, conn, req: Cohttp.Request.t, body) => {
  let req_path = Cohttp.Request.uri(req) |> Uri.path;
  let path_parts = Str.(split(regexp("/"), req_path));

  let matched_rewrite =
    Config.(
      List.find_opt(
        ({pattern}) =>
          switch (Re.exec_opt(pattern, req_path)) {
          | Some(_) => true
          | None => false
          },
        config.rewrite,
      )
    );

  switch (matched_rewrite) {
  | Some(item) => Printf.eprintf("%s %s", req_path, item.target)
  | None => ()
  };

  /*
   if req_path matches one of rewrite.pattern
   | (_, path_parts) => {
     Printf.eprintf("");
     Cohttp_lwt_unix.Server.respond_string(~status=`Not_found, ~body="", ());
   }
   */

  /*
   * then we check if the method is GET and path is ws and send it to the websocket
   * then we check if it's a GET and send it to the static handler
   * else we fail with 404
   */
  Config.(
    switch (req.meth, path_parts) {
    | (`GET, ["ws"]) => websocketHandler(conn, req, body)
    | (`GET, _) => StaticHandler.serveStatic(config.outputDir, req_path)
    | _ =>
      Cohttp_lwt_unix.Server.respond_string(~status=`Not_found, ~body="", ())
    }
  );
};

let start = (~port=3000, ~outputDir, ~rewrite, ~debug, ()) => {
  let config = Config.{port, outputDir, rewrite, debug};
  Printf.sprintf("Listening on port %d...", port) |> print_endline;

  let (broadcastToWebsocket, websocketHandler) =
    WebsocketHandler.makeHandler(~debug, ());

  let server =
    Cohttp_lwt_unix.Server.create(
      ~mode=`TCP(`Port(port)),
      Cohttp_lwt_unix.Server.make(
        ~callback=createCallback(~config, ~websocketHandler),
        (),
      ),
    );

  (broadcastToWebsocket, server);
};
