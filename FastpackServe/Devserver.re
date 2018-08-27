let createCallback =
    (
      ~output,
      ~websocketHandler,
      ~proxyHandler,
      ~shouldProxy,
      ~proxyPath,
      ~proxyPathRewrite,
      conn,
      req: Cohttp.Request.t,
      body,
    ) => {
  let req_path = Cohttp.Request.uri(req) |> Uri.path;
  let path_parts = Str.(split(regexp("/"), req_path));

  let proxyPathRewrite =
    switch (proxyPathRewrite) {
    | Some(p) => p
    | None => proxyPath
    };

  /*
   * First we check to see if the path matches our wanted proxy path
   * then we check if the method is GET and path is ws and send it to the websocket
   * then we check if it's a GET and send it to the static handler
   * else we fail with 404
   */
  switch (req.meth, path_parts, shouldProxy) {
  | (_, [apiPath], true) when apiPath == proxyPath =>
    proxyHandler(proxyPathRewrite, req, body)
  | (_, [apiPath, ...path], true) when apiPath == proxyPath =>
    proxyHandler(String.concat("/", [proxyPathRewrite, ...path]), req, body)
  | (`GET, ["ws"], _) => websocketHandler(conn, req, body)
  | (`GET, _, _) => StaticHandler.serveStatic(output, req_path)
  | _ =>
    Cohttp_lwt_unix.Server.respond_string(~status=`Not_found, ~body="", ())
  };
};

let start =
    (~port=3000, ~output, ~proxyTarget, ~proxyPath, ~proxyPathRewrite, ()) => {
  Printf.sprintf("Listening on port %d...", port) |> print_endline;

  let (host, shouldProxy) =
    switch (proxyTarget) {
    | Some(target) => (target, true)
    | None => ("", false)
    };

  let proxyHandler = ProxyHandler.makeHandler(~host);

  let (broadcastToWebsocket, websocketHandler) =
    WebsocketHandler.makeHandler(~debug=true, ());

  let server =
    Cohttp_lwt_unix.Server.create(
      ~mode=`TCP(`Port(port)),
      Cohttp_lwt_unix.Server.make(
        ~callback=
          createCallback(
            ~output,
            ~websocketHandler,
            ~proxyHandler,
            ~shouldProxy,
            ~proxyPath,
            ~proxyPathRewrite,
          ),
        (),
      ),
    );

  (broadcastToWebsocket, server);
};
