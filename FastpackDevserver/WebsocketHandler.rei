type handler =
  (
    (Conduit_lwt_unix.flow, Cohttp.Connection.t),
    Cohttp_lwt_unix.Request.t,
    Cohttp_lwt.Body.t
  ) =>
  Lwt.t((Cohttp.Response.t, Cohttp_lwt.Body.t));

let makeHandler: (~debug: bool=?, unit) => (string => Lwt.t(unit), handler);
