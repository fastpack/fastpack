type t = {
  entries: Hashtbl.t(string, (bool, option(entry))),
  locks: Hashtbl.t(string, Lwt_mutex.t),
}
and entry = {
  stats: Unix.stats,
  content: option(string),
};

let make' = (~entries=None, ()) => {
  entries: CCOpt.get_or(~default=Hashtbl.create(5000), entries),
  locks: Hashtbl.create(5000),
};

let make = () => make'();

let isEmpty = cache => Hashtbl.length(cache.entries) == 0;
let clear = cache => Hashtbl.clear(cache.entries);

let invalidate = (filename, cache) =>
  Hashtbl.remove(cache.entries, filename);

let withLock = (filename, cache, f) => {
  let lock =
    Hashtbl.get_or_add(cache.locks, ~k=filename, ~f=_ => Lwt_mutex.create());
  Lwt_mutex.with_lock(lock, f);
};

let stat = (filename, cache) =>
  withLock(filename, cache, () =>
    switch (Hashtbl.find_opt(cache.entries, filename)) {
    | Some((true, entry)) =>
      switch (entry) {
      | Some(entry) => Lwt.return(Some(entry.stats))
      | None => Lwt.return(None)
      }
    | Some((false, Some(entry))) =>
      switch%lwt (Lwt_unix.stat(filename)) {
      | stats =>
        let content =
          if (stats.st_mtime != entry.stats.Unix.st_mtime) {
            None;
          } else {
            entry.content;
          };
        Hashtbl.replace(
          cache.entries,
          filename,
          (true, Some({stats, content})),
        );
        Lwt.return(Some(stats));

      | exception (Unix.Unix_error(Unix.ENOENT, _, _)) =>
        Hashtbl.replace(cache.entries, filename, (true, None));
        Lwt.return(None);
      }
    | Some((false, None))
    | None =>
      switch%lwt (Lwt_unix.stat(filename)) {
      | stats =>
        Hashtbl.replace(
          cache.entries,
          filename,
          (true, Some({stats, content: None})),
        );
        Lwt.return(Some(stats));

      | exception (Unix.Unix_error(Unix.ENOENT, _, _)) =>
        Hashtbl.replace(cache.entries, filename, (true, None));
        Lwt.return(None);
      }
    }
  );

let exists = (filename, cache) =>
  switch%lwt (stat(filename, cache)) {
  | Some(_) => Lwt.return(true)
  | None => Lwt.return(false)
  };

let read = (filename, cache) => {
  let read' = (filename, entry) => {
    let%lwt content = Lwt_io.(with_file(~mode=Input, filename, read));
    Hashtbl.replace(
      cache.entries,
      filename,
      (true, Some({...entry, content: Some(content)})),
    );
    Lwt.return(Some(content));
  };
  withLock(filename, cache, () =>
    switch (Hashtbl.find_opt(cache.entries, filename)) {
    | Some((true, Some({content: Some(content), _}))) =>
      Lwt.return(Some(content))
    | Some((true, Some({content: None, _} as entry))) =>
      read'(filename, entry)
    | Some((true, None)) => Lwt.return(None)
    | Some((false, _)) =>
      let%lwt _ = stat(filename, cache);
      switch (Hashtbl.find_opt(cache.entries, filename)) {
      | Some((true, Some({content: Some(content), _}))) =>
        Lwt.return(Some(content))
      | Some((true, Some({content: None, _} as entry))) =>
        read'(filename, entry)
      | Some((true, None)) => Lwt.return(None)
      | _ => Lwt.fail(Failure("Impossible cache state: " ++ filename))
      };
    | None =>
      switch%lwt (Lwt_unix.stat(filename)) {
      | stats =>
        let%lwt content = Lwt_io.(with_file(~mode=Input, filename, read));
        Hashtbl.replace(
          cache.entries,
          filename,
          (true, Some({stats, content: Some(content)})),
        );
        Lwt.return(Some(content));

      | exception (Unix.Unix_error(Unix.ENOENT, _, _)) =>
        Hashtbl.replace(cache.entries, filename, (true, None));
        Lwt.return(None);
      }
    }
  );
};

let readExisting = (filename, cache) =>
  switch%lwt (read(filename, cache)) {
  | Some(content) => Lwt.return(content)
  | None => Lwt.fail(Failure("file does not exist"))
  };

type persistent = list((string, option(entry)));
let toPersistent = cache =>
  Hashtbl.map_list(
    (filename, (_, entry)) => (filename, entry),
    cache.entries,
  );

let ofPersistent = data => {
  let entries =
    Hashtbl.of_list(
      List.map(((filename, entry)) => (filename, (false, entry)), data),
    );
  make'(~entries=Some(entries), ());
};
