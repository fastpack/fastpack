type ('a, 'b) t = ('a, 'b) Run.t Lwt.t

let return v = Lwt.return (Ok v)

let error msg =
  Lwt.return (Run.error msg)

let withContext msg v =
  let%lwt v = v in
  Lwt.return (Run.withContext msg v)

let bind ~f v =
  let waitForPromise = function
    | Ok v -> f v
    | Error err -> Lwt.return (Error err)
  in
  Lwt.bind v waitForPromise

let joinAll xs =
  let rec _joinAll xs res = match xs with
    | [] ->
      return (List.rev res)
    | x::xs ->
      let f v = _joinAll xs (v::res) in
      bind ~f x
  in
  _joinAll xs []

let waitAll xs =
  let rec _waitAll xs = match xs with
    | [] -> return ()
    | x::xs ->
      let f () = _waitAll xs in
      bind ~f x
  in
  _waitAll xs

module Syntax = struct
  let return = return
  let error = error

  module Let_syntax = struct
    let bind = bind
  end
end

let liftOfRun = Lwt.return

let foldLeft ~f ~init xs =
  let rec fold acc xs =  match acc, xs with
    | Error err, _ -> Lwt.return_error err
    | Ok acc, [] -> Lwt.return_ok acc
    | Ok acc, x::xs ->
      let%lwt acc = f acc x in
      fold acc xs
  in
  fold (Ok init) xs
