open Cmdliner;
module Rewrite = {
  type t = {
    pattern_s: string,
    pattern: Re.re,
    target: string,
  };

  let ofString = s => {
    let (pattern_s, target) =
      switch (String.(s |> trim |> split_on_char(':'))) {
      | []
      | [_]
      | [_, ""] => raise(Failure("Empty config"))
      | [pattern_s, ...rest] => (
          pattern_s,
          String.(rest |> concat(":") |> trim),
        )
      };

    let pattern =
      try (Re_posix.compile_pat(pattern_s)) {
      | Re_posix.Parse_error =>
        raise(Failure("Pattern regexp parse error. Use POSIX syntax"))
      };

    {pattern_s, pattern, target};
  };

  let toString = ({pattern_s, target, _}) =>
    Printf.sprintf("%s:%s", pattern_s, target);
  let parse = s =>
    try (Result.Ok((false, ofString(s)))) {
    | Failure(msg) => Result.Error(`Msg(msg))
    };

  let print = (ppf, (_, opt)) => Format.fprintf(ppf, "%s", toString(opt));
};
/* ~rewrite=List.map(snd, rewrite), */

type t = {
  rewrite: list(Rewrite.t),
};

let term = {
  let run = rewrite => {rewrite: List.map(snd, rewrite)};
  let rewriteT = {
    let rewrite = Arg.conv(Rewrite.(parse, print));

    let doc = "Rewrite url matching the PATTERN with the TARGET.";

    let docv = "PATTERN:TARGET";
    Arg.(value & opt_all(rewrite, []) & info(["rewrite"], ~docv, ~doc));
  };

  Term.(const(run) $ rewriteT)
}
