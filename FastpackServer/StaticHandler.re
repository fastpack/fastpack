module C = Cohttp_lwt_unix;
module CServer = Cohttp_lwt_unix.Server;

let removeLeadingSeparator = path => {
  let pathLength = String.length(path);
  if (path.[0] == Filename.dir_sep.[0] && pathLength > 1) {
    String.sub(path, 1, pathLength - 1);
  } else {
    path;
  };
};

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
