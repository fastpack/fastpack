module StringSet = Set.Make(String);
module M = Map.Make(String);
module FS = FastpackUtil.FS;
module Scope = FastpackUtil.Scope;

type strategy =
  | Memory
  | Persistent(invalidate)
and invalidate = {
  currentDir: string,
  projectRootDir: string,
  mock: list((string, Config.Mock.t)),
  nodeModulesPaths: list(string),
  resolveExtension: list(string),
  preprocess: list(Preprocessor.config),
};

module ModuleEntry = {
  type t = {
    id: string,
    package: Package.t,
    module_type: Module.module_type,
    files: list((string, string)),
    source: string,
    build_dependencies: M.t(float),
    static_dependencies: list((Module.Dependency.t, Module.location)),
    dynamic_dependencies: list((Module.Dependency.t, Module.location)),
    scope: Scope.t,
    exports: Scope.exports,
  };
};

type entry = {
  exists: bool,
  st_mtime: float,
  st_kind: Unix.file_kind,
  digest: string,
  content: string,
};

type cache = {
  files: FSCache.persistent,
  modules: M.t(ModuleEntry.t),
};

type t = {
  /* file_exists: string => Lwt.t(bool), */
  /* file_stat: string => Lwt.t(Unix.stats), */
  /* file_stat_opt: string => Lwt.t(option(Unix.stats)), */
  /* get_file: string => Lwt.t(string), */
  /* get_file_no_raise: string => Lwt.t((entry, bool)), */
  /* get_package: string => Lwt.t((Package.t, bool)), */
  /* find_package_for_filename: (string, string) => Lwt.t((Package.t, bool)), */
  files: FSCache.t,
  get_module: Module.location => Lwt.t(option(Module.t)),
  add_module: Module.t => unit,
  remove_module: Module.location => unit,
  cleanup: unit => unit,
  /* add_build_dependencies: Module.t -> string list -> unit Lwt.t; */
  /* get_invalidated_modules : string -> string list; */
  /* setup_build_dependencies : StringSet.t -> unit; */
  dump: unit => Lwt.t(unit),
  starts_empty: bool,
};

exception FileDoesNotExist(string);

type init =
  | Persistent(string)
  | Memory;

let empty = {files: FSCache.(make() |> toPersistent), modules: M.empty};

let create = (strategy: strategy) => {
  let cacheId = ref("");
  let cacheFilename = ref("");
  let setCacheFilename =
      (
        ~cacheDir,
        ~currentDir,
        ~projectRootDir,
        ~mock,
        ~nodeModulesPaths,
        ~resolveExtension,
        ~preprocess,
      ) => {
    cacheId :=
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
        String.concat(",", List.map(Preprocessor.to_string, preprocess)),
      );
    cacheFilename :=
      FilePath.concat(
        cacheDir,
        String.concat(
          "-",
          [
            "cache",
            cacheId^ |> Digest.string |> Digest.to_hex,
            Version.github_commit,
          ],
        ),
      );
  };

  let%lwt loaded =
    switch (strategy) {
    | Memory => Lwt.return(empty)
    | Persistent({
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
      setCacheFilename(
        ~cacheDir,
        ~currentDir,
        ~projectRootDir,
        ~mock,
        ~nodeModulesPaths,
        ~resolveExtension,
        ~preprocess,
      );
      switch%lwt (Lwt_unix.file_exists(cacheFilename^)) {
      | true =>
        Lwt_io.with_file(
          ~mode=Lwt_io.Input, ~flags=Unix.[O_RDONLY], cacheFilename^, ch =>
          (Lwt_io.read_value(ch): Lwt.t(cache))
        )
      | false => Lwt.return(empty)
      };
    };

  let files = FSCache.ofPersistent(loaded.files);
  let modules = ref(loaded.modules);

  let get_module = location => {
    let location_str = Module.location_to_string(location);
    let build_dependencies_changed = build_dependencies =>
      build_dependencies
      |> M.bindings
      |> Lwt_list.exists_s(((filename, known_st_mtime)) =>
           switch%lwt (FSCache.stat(filename, files)) {
           | None => Lwt.return(true)
           | Some({Unix.st_mtime, _}) =>
             Lwt.return(known_st_mtime != st_mtime)
           }
         );

    switch (M.get(location_str, modules^)) {
    | None => Lwt.return_none
    | Some({
        id,
        package,
        module_type,
        files,
        source,
        build_dependencies,
        static_dependencies,
        dynamic_dependencies,
        scope,
        exports,
      }) =>
      switch%lwt (build_dependencies_changed(build_dependencies)) {
      | true =>
        modules := M.remove(location_str, modules^);
        Lwt.return_none;
      | false =>
        Lwt.return_some({
          Module.id,
          location,
          package,
          static_dependencies,
          dynamic_dependencies,
          build_dependencies,
          module_type,
          files,
          source,
          scope,
          exports,
        })
      }
    };
  };

  let remove_module = (location: Module.location) => {
    let location_str = Module.location_to_string(location);
    modules := M.remove(location_str, modules^);
  };

  let cleanup = () =>
    FSCache.clear(
      files,
      /* modules := M.empty; */
    );

  let add_module = (m: Module.t) =>
    switch (m.location) {
    | Module.EmptyModule
    | Module.Runtime => ()
    | _ =>
      let location_str = Module.location_to_string(m.location);
      let module_entry = {
        ModuleEntry.id: m.id,
        package: m.package,
        build_dependencies: m.build_dependencies,
        static_dependencies: m.static_dependencies,
        dynamic_dependencies: m.dynamic_dependencies,
        module_type: m.module_type,
        files: m.files,
        scope: m.scope,
        exports: m.exports,
        source: m.source,
      };

      modules := M.add(location_str, module_entry, modules^);
    };

  let dump = () =>
    if (cacheFilename^ != "") {
      let tempDir = FilePath.dirname(cacheFilename^);
      let suffix = FilePath.basename(cacheFilename^);
      let%lwt () = FS.makedirs(tempDir);
      let (tempFile, _) =
        Filename.open_temp_file(
          ~perms=0o644,
          ~temp_dir=tempDir,
          ".fpack",
          suffix,
        );

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
            {files: FSCache.toPersistent(files), modules: modules^},
          )
        );

      Lwt.finalize(
        () =>
          switch%lwt (Lwt_unix.rename(tempFile, cacheFilename^)) {
          | () => Lwt.return_unit
          | exception (Sys_error(_)) => Lwt.return_unit
          },
        () =>
          if%lwt (Lwt_unix.file_exists(tempFile)) {
            Lwt_unix.unlink(tempFile);
          },
      );
    } else {
      Lwt.return_unit;
    };

  Lwt.return({
    files,
    get_module,
    add_module,
    remove_module,
    cleanup,
    dump,
    starts_empty: FSCache.isEmpty(files),
  });
};
