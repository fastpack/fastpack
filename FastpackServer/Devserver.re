let createCallback =
    (~outputDir, ~websocketHandler, conn, req: Cohttp.Request.t, body) => {
  let req_path = Cohttp.Request.uri(req) |> Uri.path;
  let path_parts = Str.(split(regexp("/"), req_path));

  /*
   * then we check if the method is GET and path is ws and send it to the websocket
   * then we check if it's a GET and send it to the static handler
   * else we fail with 404
   */
  switch (req.meth, path_parts) {
  | (`GET, ["ws"]) => websocketHandler(conn, req, body)
  | (`GET, _) => StaticHandler.serveStatic(outputDir, req_path)
  | _ =>
    Cohttp_lwt_unix.Server.respond_string(~status=`Not_found, ~body="", ())
  };
};

let start = (~config: Config.t, ~outputDir, ~debug, ()) => {
  let url = "http://localhost:" ++ string_of_int(config.port);
  let urlWithColor =
    FastpackUtil.Colors.print_with_color(~font=Bold, url, Cyan);
  Printf.sprintf("Server running at %s", urlWithColor) |> print_endline;

  let (broadcastToWebsocket, websocketHandler) =
    WebsocketHandler.makeHandler(~debug, ());

  let server =
    Cohttp_lwt_unix.Server.create(
      ~mode=`TCP(`Port(config.port)),
      Cohttp_lwt_unix.Server.make(
        ~callback=createCallback(~outputDir, ~websocketHandler),
        (),
      ),
    );

  (broadcastToWebsocket, server);
};