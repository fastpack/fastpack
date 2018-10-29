open Cmdliner;

type t = {port: int};
let portT = {
  let doc = "Port for development server to listen on";
  let docv = "NUMBER";
  Arg.(value & opt(int, 3000) & info(["p", "port"], ~docv, ~doc));
};

let term = {
  let run = port => {port: port};
  Term.(const(run) $ portT);
};
