type t('a, 'b) = Lwt.t(Run.t('a, 'b));

let return = v => Lwt.return(Ok(v));

let error = msg => Lwt.return(Run.error(msg));

let withContext = (msg, v) => {
  let%lwt v = v;
  Lwt.return(Run.withContext(msg, v));
};

let bind = (~f, v) => {
  let waitForPromise =
    fun
    | Ok(v) => f(v)
    | Error(err) => Lwt.return(Error(err));

  Lwt.bind(v, waitForPromise);
};

let joinAll = xs => {
  let rec _joinAll = (xs, res) =>
    switch (xs) {
    | [] => return(List.rev(res))
    | [x, ...xs] =>
      let f = v => _joinAll(xs, [v, ...res]);
      bind(~f, x);
    };

  _joinAll(xs, []);
};

let waitAll = xs => {
  let rec _waitAll = xs =>
    switch (xs) {
    | [] => return()
    | [x, ...xs] =>
      let f = () => _waitAll(xs);
      bind(~f, x);
    };

  _waitAll(xs);
};

module Syntax = {
  let return = return;
  let error = error;

  module Let_syntax = {
    let bind = bind;
  };
};

let liftOfRun = Lwt.return;

let foldLeft = (~f, ~init, xs) => {
  let rec fold = (acc, xs) =>
    switch (acc, xs) {
    | (Error(err), _) => Lwt.return_error(err)
    | (Ok(acc), []) => Lwt.return_ok(acc)
    | (Ok(acc), [x, ...xs]) =>
      let%lwt acc = f(acc, x);
      fold(acc, xs);
    };

  fold(Ok(init), xs);
};
