module C = Cohttp_lwt_unix;
module CServer = Cohttp_lwt_unix.Server;

let serveStatic = (base, path) => {
  let fname = Filename.concat(base, path);
  if (Sys.file_exists(fname)) {
    if (Sys.is_directory(fname)) {
      if (Sys.file_exists(Filename.concat(fname, "index.html"))) {
        CServer.respond_file(
          ~fname=Filename.concat(fname, "index.html"),
          (),
        );
      } else {
        C.Server.respond_string(~status=`Not_found, ~body="", ());
      };
    } else {
      CServer.respond_file(~fname, ());
    };
  } else if (Sys.file_exists(fname ++ ".html")) {
    CServer.respond_file(~fname=fname ++ ".html", ());
  } else if (Sys.file_exists(base ++ "index.html")) {
    C.Server.respond_file(~fname=Filename.concat(base, "index.html"), ());
  } else {
    C.Server.respond_string(~status=`Not_found, ~body="", ());
  };
};

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
  | (`GET, _, _) => serveStatic(output, req_path)
  | _ => C.Server.respond_string(~status=`Not_found, ~body="", ())
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
    C.Server.create(
      ~mode=`TCP(`Port(port)),
      C.Server.make(
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
