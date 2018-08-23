/**
 * Computation with structured error reporting.
 */

type t('a, 'b) = result('a, error('b))
and error('b) = ('b, context)
and context = list(string);

let return = v => Ok(v);

let error = msg => Error((msg, []));

let bind = (~f, v) =>
  switch (v) {
  | Ok(v) => f(v)
  | Error(err) => Error(err)
  };

module Syntax = {
  let return = return;
  let error = error;
  module Let_syntax = {
    let bind = bind;
  };
};

let withContext = (line, v) =>
  switch (v) {
  | Ok(v) => Ok(v)
  | Error((msg, context)) => Error((msg, [line, ...context]))
  };

let liftOfStringError = v =>
  switch (v) {
  | Ok(v) => Ok(v)
  | Error(line) => Error((line, []))
  };

let formatError = ((msg, context)) =>
  context
  |> List.map(line => "  " ++ line)
  |> (context => [msg, ...context])
  |> String.concat("\n");

let foldLeft = (~f, ~init, xs) => {
  let rec fold = (acc, xs) =>
    switch (acc, xs) {
    | (Error(err), _) => Error(err)
    | (Ok(acc), []) => Ok(acc)
    | (Ok(acc), [x, ...xs]) => fold(f(acc, x), xs)
    };

  fold(Ok(init), xs);
};

let rec waitAll =
  fun
  | [] => return()
  | [x, ...xs] => {
      let f = () => waitAll(xs);
      bind(~f, x);
    };
