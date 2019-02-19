module StringSet = Set.Make(CCString);
module M = Map.Make(CCString);

type t = {
  entries: Hashtbl.t(string, (bool, option(entry))),
  locks: Hashtbl.t(string, Lwt_mutex.t),
}
and entry =
  | Link(string)
  | File(file)
  | Dir(dir)
and file = {
  stats: Unix.stats,
  content: option(string),
}
and dir = {
  dirStats: Unix.stats,
  files: StringSet.t,
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
        | Some((true, Some(File(entry)))) => Lwt.return(Some(entry.stats))

        | Some((true, Some(Dir(entry)))) =>
          Lwt.return(Some(entry.dirStats))

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
            | Lwt_unix.S_DIR =>
              let%lwt files =
                Lwt_stream.to_list(Lwt_unix.files_of_directory(filename));
              Hashtbl.replace(
                cache.entries,
                filename,
                (
                  true,
                  Some(
                    Dir({
                      dirStats: stats,
                      files:
                        files
                        |> List.filter(filename =>
                             filename != "." && filename != ".."
                           )
                        |> StringSet.of_list,
                    }),
                  ),
                ),
              );
              Lwt.return(Some(stats));
            | _ =>
              let content =
                switch (entry) {
                | File({stats: cachedStats, content})
                    when stats.st_mtime == cachedStats.Unix.st_mtime => content
                | _ => None
                };
              Hashtbl.replace(
                cache.entries,
                filename,
                (true, Some(File({stats, content}))),
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
            | Lwt_unix.S_DIR =>
              let%lwt files =
                Lwt_stream.to_list(Lwt_unix.files_of_directory(filename));
              Hashtbl.replace(
                cache.entries,
                filename,
                (
                  true,
                  Some(
                    Dir({
                      dirStats: stats,
                      files:
                        files
                        |> List.filter(filename =>
                             filename != "." && filename != ".."
                           )
                        |> StringSet.of_list,
                    }),
                  ),
                ),
              );
              Lwt.return(Some(stats));
            | _ =>
              Hashtbl.replace(
                cache.entries,
                filename,
                (true, Some(File({stats, content: None}))),
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

let readdir = (filename, cache) => {
  let rec readdir' = (~seen=StringSet.empty, filename) =>
    switch (StringSet.find_opt(filename, seen)) {
    | Some(_) => failwith("links cycle in cache")
    | None =>
      withLock(filename, cache, () =>
        switch (Hashtbl.find_opt(cache.entries, filename)) {
        /* trusted symlink, always go to target */
        | Some((true, Some(Link(target)))) =>
          readdir'(~seen=StringSet.add(filename, seen), target)

        /* trusted entry, has stats */
        | Some((true, Some(File(_)))) => Lwt.return_none

        | Some((true, Some(Dir(entry)))) => Lwt.return_some(entry.files)

        /* trusted entry, no stats */
        | Some((true, None)) => Lwt.return_none

        | Some((false, _))
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
              readdir'(~seen=StringSet.add(filename, seen), target);
            | Lwt_unix.S_DIR =>
              let%lwt files =
                Lwt_stream.to_list(Lwt_unix.files_of_directory(filename));
              let files =
                files
                |> List.filter(filename =>
                     filename != "." && filename != ".."
                   )
                |> StringSet.of_list;
              Hashtbl.replace(
                cache.entries,
                filename,
                (true, Some(Dir({dirStats: stats, files}))),
              );
              Lwt.return_some(files);
            | _ =>
              Hashtbl.replace(
                cache.entries,
                filename,
                (true, Some(File({stats, content: None}))),
              );
              Lwt.return_none;
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
  readdir'(filename);
};

type exactMatch =
  | Exact
  | CaseInsensitive(string, list(string))
  | CaseInsensitiveUTF(string)
  | MisMatch;

let caseSensitiveExactMatch = (filename, cache) =>
  switch%lwt (stat(filename, cache)) {
  | None => Lwt.return(MisMatch)
  | Some(_) =>
    let dirname = FilePath.dirname(filename);
    let basename = FilePath.basename(filename);
    switch%lwt (readdir(dirname, cache)) {
    | Some(files) =>
      StringSet.mem(basename, files) ?
        Lwt.return(Exact) :
        {
          let fileMap =
            List.fold_left(
              (fileMap, f) =>
                M.update(
                  String.lowercase_ascii(f),
                  fs =>
                    switch (fs) {
                    | Some(fs) => Some([f, ...fs])
                    | None => Some([f])
                    },
                  fileMap,
                ),
              M.empty,
              StringSet.elements(files),
            );
          switch(M.find_opt(String.lowercase_ascii(basename), fileMap)) {
          | Some(fs) => Lwt.return(CaseInsensitive(dirname, fs))
          | None => Lwt.return(CaseInsensitiveUTF(dirname))
          }
        }
    | None =>
      /* TODO: report better here */
      Lwt.return(MisMatch)
    };
  };

let read = (filename, cache) => {
  let readBinary =
    switch (Sys.os_type) {
    | "Unix" => (
        filename =>
          switch%lwt (Lwt_io.(with_file(~mode=Input, filename, read))) {
          | content => Lwt.return_some(content)
          | exception (Unix.Unix_error(Unix.ENOENT, _, _)) => Lwt.return_none
          | exception (Sys_error(_)) => Lwt.return_none
          }
      )
    | _ => (
        filename =>
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
          }
      )
    };
  let readAndUpdateContent = (filename, entry) =>
    switch%lwt (readBinary(filename)) {
    | Some(_) as content =>
      Hashtbl.replace(
        cache.entries,
        filename,
        (true, Some(File({...entry, content}))),
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
        | Some((true, Some(Dir(_)))) =>
          Lwt.fail(
            Failure(
              Printf.sprintf(
                "Trying to read directory as file: %s",
                filename,
              ),
            ),
          )
        | Some((true, Some(File({content: Some(content), _})))) =>
          Lwt.return(Some(content))

        /* trusted entry without content, this means that stat was called, but not read */
        | Some((true, Some(File({content: None, _} as entry)))) =>
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
          | Some((true, Some(File({content: Some(content), _})))) =>
            Lwt.return(Some(content))

          /* trusted entry without content, this means that stat was called, but not read */
          | Some((true, Some(File({content: None, _} as entry)))) =>
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
                  (true, Some(File({stats, content}))),
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
