open Lwt;
open Cohttp_lwt_unix;

let makeHandler = (~host, path, req: Cohttp.Request.t, body) => {
  let proxyPath = host ++ path;
  let proxyUri = Uri.of_string(proxyPath);
  let host = Uri.host(proxyUri);

  let headers =
    (
      switch (host) {
      | Some(host) => Cohttp.Header.replace(req.headers, "Host", host)
      | None => Cohttp.Header.remove(req.headers, "Host")
      }
    )
    |> Cohttp.Header.remove(_, "Origin");

  (
    switch (req.meth) {
    | `GET => Client.get(~headers, proxyUri)
    | `POST => Client.post(~body, ~headers, proxyUri)
    | `PUT => Client.put(~body, ~headers, proxyUri)
    | `PATCH => Client.patch(~body, ~headers, proxyUri)
    | `DELETE => Client.delete(~body, ~headers, proxyUri)
    | _ => Client.get(proxyUri)
    }
  )
  >>= (
    ((resp, body)) => {
      let headers = resp |> Response.headers;
      let status = resp |> Response.status;

      Cohttp_lwt_unix.Server.respond(~headers, ~body, ~status, ());
    }
  );
};
