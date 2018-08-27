open FastpackUtil;

let copy = (~source, ~output, ~port, ()) =>
  Lwt.(
    FS.makedirs(output)
    >>= (
      _ =>
        FS.copy_file(
          ~source=source ++ "/index.html",
          ~target=output ++ "/index.html",
          (),
        )
    )
    >>= (
      _ => {
        let%lwt sourceFile =
          Lwt_io.open_file(~mode=Lwt_io.Input, output ++ "/index.html");

        let%lwt indexHtml = Lwt_io.read(sourceFile);

        let%lwt () = Lwt_io.close(sourceFile);

        let indexHtml =
          Str.replace_first(
            Str.regexp("</body>"),
            Printf.sprintf(
              {|<script type="text/javascript" src="/index.js"></script>
  <script>
    const ws = new WebSocket("ws://localhost:%d/ws");

    ws.addEventListener("open", event => {
      ws.send("hello");
    });

    ws.addEventListener("message", event => {
      console.log(event.data);
      if (event.data !== "hello") {
        const data = JSON.parse(event.data);
        console.log(data);
        if (data.error) {
          console.log(data.error);
          document.querySelector("#index").innerHTML = `<pre>${data.error}</pre>`;
        } else {
          debugger;
          window.location.reload();
        }
      }
    });
  </script>
</body>|},
              port,
            ),
            indexHtml,
          );

        let%lwt targetFile =
          Lwt_io.open_file(~mode=Lwt_io.Output, output ++ "/index.html");

        Lwt_io.write(targetFile, indexHtml)
        >>= (() => Lwt_io.close(targetFile));
      }
    )
  );
