module StringSet = Set.Make(String);
module M = Map.Make(String);
module FS = FastpackUtil.FS;
module Scope = FastpackUtil.Scope;

type load =
  | Empty
  | Load(params)
and params = {
  currentDir: string,
  projectRootDir: string,
  mock: list((string, Config.Mock.t)),
  nodeModulesPaths: list(string),
  resolveExtension: list(string),
  preprocess: list(Config.Preprocessor.t),
};

type save =
  | No
  | Filename(string);

type t = {
  loaded: load,
  save,
  files: FSCache.t,
  modules: Hashtbl.t(Module.location, Module.t),
};

type persistent = {
  files: FSCache.persistent,
  modules: list((Module.location, Module.t)),
};

/* let empty = {files: FSCache.(make() |> toPersistent), modules: M.empty}; */

let make = (load: load) =>
  switch (load) {
  | Empty =>
    {
      files: FSCache.make(),
      modules: Hashtbl.create(5000),
      loaded: Empty,
      save: No,
    }
    |> Lwt.return
  | Load({
      currentDir,
      projectRootDir,
      mock,
      nodeModulesPaths,
      resolveExtension,
      preprocess,
    }) =>
    let node_modules = FilePath.concat(currentDir, "node_modules");
    let%lwt cacheDir =
      switch%lwt (FS.try_dir(node_modules)) {
      | Some(dir) =>
        FilePath.concat(FilePath.concat(dir, ".cache"), "fpack")
        |> Lwt.return
      | None =>
        FilePath.concat(FilePath.concat(currentDir, ".cache"), "fpack")
        |> Lwt.return
      };
    let%lwt () = FS.makedirs(cacheDir);
    let id =
      Printf.sprintf(
        {|
    Current Directory: %s
    Project Root Directory: %s
    Mocks: %s
    Node Modules Paths: %s
    Extensions: %s
    Preprocessors: %s
    |},
        currentDir,
        projectRootDir,
        String.concat(",", List.map(Config.Mock.to_string, mock)),
        String.concat(",", nodeModulesPaths),
        String.concat(",", resolveExtension),
        String.concat(
          ",",
          List.map(Config.Preprocessor.toString, preprocess),
        ),
      );
    let filename =
      FilePath.concat(
        cacheDir,
        String.concat(
          "-",
          [
            "cache",
            id |> Digest.string |> Digest.to_hex,
            Version.github_commit,
          ],
        ),
      );
    switch%lwt (Lwt_unix.file_exists(filename)) {
    | true =>
      let%lwt {files, modules} =
        Lwt_io.with_file(
          ~mode=Lwt_io.Input, ~flags=Unix.[O_RDONLY], filename, ch =>
          (Lwt_io.read_value(ch): Lwt.t(persistent))
        );
      {
        files: FSCache.ofPersistent(files),
        modules: CCHashtbl.of_list(modules),
        loaded: load,
        save: Filename(filename),
      }
      |> Lwt.return;
    | false =>
      {
        files: FSCache.make(),
        modules: Hashtbl.create(5000),
        loaded: Empty,
        save: Filename(filename),
      }
      |> Lwt.return
    };
  };

let isLoadedEmpty = cache => cache.loaded == Empty;

let addModule = (m: Module.t, cache: t) =>
  Hashtbl.replace(cache.modules, m.location, m);

let removeModule = (location: Module.location, cache: t) =>
  Hashtbl.remove(cache.modules, location);

let getModule = (location: Module.location, cache: t) =>
  switch (Hashtbl.find_opt(cache.modules, location)) {
  | None => Lwt.return_none
  | Some((m: Module.t)) =>
    let build_dependencies_changed =
      m.build_dependencies
      |> M.bindings
      |> Lwt_list.exists_s(((filename, known_st_mtime)) =>
           switch%lwt (FSCache.stat(filename, cache.files)) {
           | None => Lwt.return(true)
           | Some({Unix.st_mtime, _}) =>
             Lwt.return(known_st_mtime != st_mtime)
           }
         );
    switch%lwt (build_dependencies_changed) {
    | true =>
      removeModule(m.location, cache);
      Lwt.return_none;
    | false => Lwt.return(Some(m))
    };
  };

let save = cache =>
  switch (cache.save) {
  | No => Lwt.return_unit
  | Filename(filename) =>
    let tempDir = FilePath.dirname(filename);
    let suffix = FilePath.basename(filename);
    let%lwt () = FS.makedirs(tempDir);
    let (tempFile, oc) =
      Filename.open_temp_file(
        ~perms=0o644,
        ~temp_dir=tempDir,
        ".fpack",
        suffix,
      );
    close_out(oc);

    let%lwt () =
      Lwt_io.with_file(
        ~mode=Lwt_io.Output,
        ~perm=0o644,
        ~flags=Unix.[O_CREAT, O_TRUNC, O_RDWR],
        tempFile,
        ch =>
        Lwt_io.write_value(
          ch,
          ~flags=[],
          {
            files: FSCache.toPersistent(cache.files),
            modules: CCHashtbl.to_list(cache.modules),
          },
        )
      );

    Lwt.finalize(
      () =>
        switch%lwt (Lwt_unix.rename(tempFile, filename)) {
        | () => Lwt.return_unit
        | exception (Sys_error(_)) => Lwt.return_unit
        },
      () =>
        if%lwt (Lwt_unix.file_exists(tempFile)) {
          Lwt_unix.unlink(tempFile);
        },
    );
  };

let getFilename = cache =>
  switch (cache.save) {
  | No => None
  | Filename(filename) => Some(filename)
  };

module File = {
  let invalidate = (filename, cache: t) =>
    FSCache.invalidate(filename, cache.files);
  let exists = (filename, cache: t) => FSCache.exists(filename, cache.files);
  let stat = (filename, cache: t) => FSCache.stat(filename, cache.files);
  let read = (filename, cache: t) => FSCache.read(filename, cache.files);
  let readExisting = (filename, cache: t) =>
    FSCache.readExisting(filename, cache.files);
};
