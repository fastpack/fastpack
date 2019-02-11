module StringSet = Set.Make(CCString);

type t = {
  entries: Hashtbl.t(string, (bool, option(entry))),
  locks: Hashtbl.t(string, Lwt_mutex.t),
}
and entry =
  | Link(string)
  | Entry(data)
and data = {
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

let withLock = (filename, cache, f) => {
  let lock =
    CCHashtbl.get_or_add(cache.locks, ~k=filename, ~f=_ => Lwt_mutex.create());
  Lwt_mutex.with_lock(lock, f);
};

let invalidate = (filename, cache) =>
  withLock(filename, cache, () =>
    Lwt.return(Hashtbl.remove(cache.entries, filename))
  );

let stat = (filename, cache) => {
  let rec stat' = (~seen=StringSet.empty, filename) =>
    switch (StringSet.find_opt(filename, seen)) {
    | Some(_) => failwith("links cycle in cache")
    | None =>
      withLock(filename, cache, () =>
        switch (Hashtbl.find_opt(cache.entries, filename)) {
        /* trusted symlink, always go to target */
        | Some((true, Some(Link(target)))) =>
          stat'(~seen=StringSet.add(filename, seen), target)

        /* trusted entry, has stats */
        | Some((true, Some(Entry(entry)))) =>
          Lwt.return(Some(entry.stats))

        /* trusted entry, no stats */
        | Some((true, None)) => Lwt.return(None)

        /* not trusted entry, but we have some info */
        | Some((false, Some(entry))) =>
          switch%lwt (Lwt_unix.lstat(filename)) {
          | stats =>
            switch (stats.st_kind) {
            | Lwt_unix.S_LNK =>
              let%lwt target = FastpackUtil.FS.readlink(filename);
              Hashtbl.replace(
                cache.entries,
                filename,
                (true, Some(Link(target))),
              );
              stat'(~seen=StringSet.add(filename, seen), target);
            | _ =>
              let content =
                switch (entry) {
                | Entry({stats: cachedStats, content})
                    when stats.st_mtime == cachedStats.Unix.st_mtime => content
                | _ => None
                };
              Hashtbl.replace(
                cache.entries,
                filename,
                (true, Some(Entry({stats, content}))),
              );
              Lwt.return(Some(stats));
            }
          | exception (Sys_error(_)) =>
            Hashtbl.replace(cache.entries, filename, (true, None));
            Lwt.return(None);
          | exception (Unix.Unix_error(Unix.ENOENT, _, _)) =>
            Hashtbl.replace(cache.entries, filename, (true, None));
            Lwt.return(None);
          }
        | Some((false, None))
        | None =>
          switch%lwt (Lwt_unix.lstat(filename)) {
          | stats =>
            switch (stats.st_kind) {
            | Lwt_unix.S_LNK =>
              let%lwt target = FastpackUtil.FS.readlink(filename);
              Hashtbl.replace(
                cache.entries,
                filename,
                (true, Some(Link(target))),
              );
              stat'(~seen=StringSet.add(filename, seen), target);
            | _ =>
              Hashtbl.replace(
                cache.entries,
                filename,
                (true, Some(Entry({stats, content: None}))),
              );
              Lwt.return(Some(stats));
            }

          | exception (Sys_error(_)) =>
            Hashtbl.replace(cache.entries, filename, (true, None));
            Lwt.return(None);
          | exception (Unix.Unix_error(Unix.ENOENT, _, _)) =>
            Hashtbl.replace(cache.entries, filename, (true, None));
            Lwt.return(None);
          }
        }
      )
    };
  stat'(filename);
};

let exists = (filename, cache) =>
  switch%lwt (stat(filename, cache)) {
  | Some(_) => Lwt.return(true)
  | None => Lwt.return(false)
  };

let read = (filename, cache) => {
  let readBinary = filename =>
    switch%lwt (Lwt_io.file_length(filename)) {
    | length =>
      let readBinary' = () => {
        let ch = open_in_bin(filename);
        let content = really_input_string(ch, Int64.to_int(length));
        close_in_noerr(ch);
        Some(content);
      };
      let content =
        try (readBinary'()) {
        | Unix.Unix_error(Unix.ENOENT, _, _) => None
        | Sys_error(_) => None
        };
      Lwt.return(content);
    | exception (Unix.Unix_error(Unix.ENOENT, _, _)) => Lwt.return_none
    | exception (Sys_error(_)) => Lwt.return_none
    };

  let readAndUpdateContent = (filename, entry) =>
    switch%lwt (readBinary(filename)) {
    | Some(_) as content =>
      Hashtbl.replace(
        cache.entries,
        filename,
        (true, Some(Entry({...entry, content}))),
      );
      Lwt.return(content);
    | None =>
      Hashtbl.replace(cache.entries, filename, (true, None));
      Lwt.return_none;
    };
  let rec read' = (~seen=StringSet.empty, filename) =>
    switch (StringSet.find_opt(filename, seen)) {
    | Some(_) => failwith("read: links cycle in cache")
    | None =>
      withLock(filename, cache, () =>
        switch (Hashtbl.find_opt(cache.entries, filename)) {
        /* trusted symlink, always go to target */
        | Some((true, Some(Link(target)))) =>
          read'(~seen=StringSet.add(filename, seen), target)

        /* trusted entry, content exists */
        | Some((true, Some(Entry({content: Some(content), _})))) =>
          Lwt.return(Some(content))

        /* trusted entry without content, this means that stat was called, but not read */
        | Some((true, Some(Entry({content: None, _} as entry)))) =>
          readAndUpdateContent(filename, entry)

        /* trusted entry, file does not exist */
        | Some((true, None)) => Lwt.return(None)

        | Some((false, _)) =>
          let%lwt _ = stat(filename, cache);
          switch (Hashtbl.find_opt(cache.entries, filename)) {
          /* trusted symlink, always go to target */
          | Some((true, Some(Link(target)))) =>
            read'(~seen=StringSet.add(filename, seen), target)

          /* trusted entry, content exists */
          | Some((true, Some(Entry({content: Some(content), _})))) =>
            Lwt.return(Some(content))

          /* trusted entry without content, this means that stat was called, but not read */
          | Some((true, Some(Entry({content: None, _} as entry)))) =>
            readAndUpdateContent(filename, entry)

          /* trusted entry, file does not exist */
          | Some((true, None)) => Lwt.return(None)
          | _ => Lwt.fail(Failure("Impossible cache state: " ++ filename))
          };
        | None =>
          switch%lwt (Lwt_unix.lstat(filename)) {
          | stats =>
            switch (stats.st_kind) {
            | Lwt_unix.S_LNK =>
              let%lwt target = FastpackUtil.FS.readlink(filename);
              Hashtbl.replace(
                cache.entries,
                filename,
                (true, Some(Link(target))),
              );
              read'(~seen=StringSet.add(filename, seen), target);
            | _ =>
              switch%lwt (readBinary(filename)) {
              | Some(_) as content =>
                Hashtbl.replace(
                  cache.entries,
                  filename,
                  (true, Some(Entry({stats, content}))),
                );
                Lwt.return(content);
              | None =>
                Hashtbl.replace(cache.entries, filename, (true, None));
                Lwt.return_none;
              }
            }

          | exception (Sys_error(_)) =>
            Hashtbl.replace(cache.entries, filename, (true, None));
            Lwt.return(None);
          | exception (Unix.Unix_error(Unix.ENOENT, _, _)) =>
            Hashtbl.replace(cache.entries, filename, (true, None));
            Lwt.return(None);
          }
        }
      )
    };

  read'(filename);
};

let readExisting = (filename, cache) =>
  switch%lwt (read(filename, cache)) {
  | Some(content) => Lwt.return(content)
  | None => Lwt.fail(Failure("file does not exist"))
  };

type persistent = list((string, option(entry)));
let toPersistent = cache =>
  CCHashtbl.map_list(
    (filename, (_, entry)) => (filename, entry),
    cache.entries,
  );

let ofPersistent = data => {
  let entries =
    CCHashtbl.of_list(
      List.map(((filename, entry)) => (filename, (false, entry)), data),
    );
  make'(~entries=Some(entries), ());
};
