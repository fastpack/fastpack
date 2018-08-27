open FastpackUtil;

let copy = (~sourceDir, ~outputDir, ~outputFilename, ~port, ()) =>
  Lwt.(
    FS.makedirs(outputDir)
    >>= (
      _ =>
        FS.copy_file(
          ~source=sourceDir ++ "/index.html",
          ~target=outputDir ++ "/index.html",
          (),
        )
    )
    >>= (
      _ => {
        let%lwt sourceFile =
          Lwt_io.open_file(~mode=Lwt_io.Input, outputDir ++ "/index.html");

        let%lwt indexHtml = Lwt_io.read(sourceFile);

        let%lwt () = Lwt_io.close(sourceFile);

        let indexHtml =
          Str.replace_first(
            Str.regexp("</body>"),
            Printf.sprintf(
              {|<script type="text/javascript" src="/%s"></script>
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
          const errorElement = document.createElement("pre");
          errorElement.innerText = `${data.error}`;
          document.body.appendChild(errorElement);
        } else {
          window.location.reload();
        }
      }
    });
  </script>
</body>|},
              outputFilename,
              port,
            ),
            indexHtml,
          );

        let%lwt targetFile =
          Lwt_io.open_file(~mode=Lwt_io.Output, outputDir ++ "/index.html");

        Lwt_io.write(targetFile, indexHtml)
        >>= (() => Lwt_io.close(targetFile));
      }
    )
  );
