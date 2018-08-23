module StringSet = Set.Make(String);
module M = Map.Make(String);
module FS = FastpackUtil.FS;
module Scope = FastpackUtil.Scope;

let debug = Logs.debug;

module ModuleEntry = {
  type t = {
    id: string,
    state: Module.state,
    package: Package.t,
    module_type: Module.module_type,
    files: list((string, string)),
    content: string,
    build_dependencies: M.t(string),
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
  package: option(Package.t),
};

type cache = {
  files: M.t(entry),
  modules: M.t(ModuleEntry.t),
};

type t = {
  file_exists: string => Lwt.t(bool),
  file_stat: string => Lwt.t((entry, bool)),
  file_stat_opt: string => Lwt.t(option((entry, bool))),
  get_file: string => Lwt.t((entry, bool)),
  get_file_no_raise: string => Lwt.t((entry, bool)),
  get_package: string => Lwt.t((Package.t, bool)),
  find_package_for_filename: (string, string) => Lwt.t((Package.t, bool)),
  get_module: Module.location => Lwt.t(option(Module.t)),
  modify_content: (Module.t, string) => unit,
  /* add_build_dependencies: Module.t -> string list -> unit Lwt.t; */
  /* get_invalidated_modules : string -> string list; */
  /* setup_build_dependencies : StringSet.t -> unit; */
  remove: string => unit,
  dump: unit => Lwt.t(unit),
  starts_empty: bool,
};

exception FileDoesNotExist(string);

type strategy =
  | Use
  | Disable;

type init =
  | Persistent(string)
  | Memory;

let empty = {files: M.empty, modules: M.empty};

let create = (init: init) => {
  let no_file = {
    exists: false,
    st_mtime: 0.0,
    st_kind: Unix.S_REG,
    digest: "",
    content: "",
    package: None,
  };

  let%lwt loaded =
    switch (init) {
    | Memory => Lwt.return(empty)
    | Persistent(filename) =>
      switch%lwt (Lwt_unix.file_exists(filename)) {
      | true =>
        let%lwt loaded =
          Lwt_io.with_file(
            ~mode=Lwt_io.Input, ~flags=Unix.[O_RDONLY], filename, ch =>
            (Lwt_io.read_value(ch): Lwt.t(cache))
          );

        Lwt.return(loaded);
      | false => Lwt.return(empty)
      }
    };

  let trusted = ref(StringSet.empty);
  let add_trusted = filename => trusted := StringSet.add(filename, trusted^);

  let files = ref(loaded.files);
  let update = (filename, entry) => {
    files := M.add(filename, entry, files^);
    add_trusted(filename);
  };

  let modules = ref(loaded.modules);

  let validate = (filename, entry) => {
    let validate_file = () =>
      switch%lwt (FS.stat_option(filename)) {
      | None =>
        update(filename, no_file);
        Lwt.return((no_file, false));
      | Some({st_mtime, st_kind, _}) =>
        if (st_mtime == entry.st_mtime) {
          add_trusted(filename);
          Lwt.return((entry, true));
        } else {
          let%lwt content = Lwt_io.(with_file(~mode=Input, filename, read));
          let digest = Digest.string(content);
          if (digest == entry.digest) {
            let entry = {...entry, st_mtime, st_kind};
            update(filename, entry);
            Lwt.return((entry, true));
          } else {
            let entry = {...entry, st_mtime, st_kind, digest, content};
            update(filename, entry);
            Lwt.return((entry, false));
          };
        }
      };

    switch (entry) {
    | {package: Some(_), _} =>
      let%lwt (entry, cached) = validate_file();
      if (cached) {
        Lwt.return((entry, true));
      } else {
        let package = Package.of_json(filename, entry.content);
        let entry = {...entry, package: Some(package)};
        update(filename, entry);
        Lwt.return((entry, false));
      };
    | {digest, st_mtime, _} =>
      if (digest != "") {
        validate_file();
      } else if (st_mtime != 0.0) {
        switch%lwt (FS.stat_option(filename)) {
        | None =>
          update(filename, no_file);
          Lwt.return((no_file, false));
        | Some({st_mtime, st_kind, _}) =>
          if (st_mtime == entry.st_mtime) {
            add_trusted(filename);
            Lwt.return((entry, true));
          } else {
            let entry = {...entry, st_mtime, st_kind};
            update(filename, entry);
            Lwt.return((entry, false));
          }
        };
      } else {
        let%lwt exists = Lwt_unix.file_exists(filename);
        let entry = {...no_file, exists};
        update(filename, entry);
        Lwt.return((entry, false));
      }
    };
  };

  let file_exists = filename =>
    switch (StringSet.mem(filename, trusted^), M.get(filename, files^)) {
    | (true, Some({exists, _})) => Lwt.return(exists)
    | (_, None) =>
      let%lwt exists = Lwt_unix.file_exists(filename);
      update(filename, {...no_file, exists});
      Lwt.return(exists);
    | (false, Some(entry)) =>
      let%lwt ({exists, _}, _) = validate(filename, entry);
      Lwt.return(exists);
    };

  let file_stat = path => {
    let read_stats = () =>
      switch%lwt (FS.stat_option(path)) {
      | None =>
        update(path, no_file);
        Lwt.fail(FileDoesNotExist(path));
      | Some({st_mtime, st_kind, _}) =>
        let entry = {...no_file, exists: true, st_mtime, st_kind};
        update(path, entry);
        Lwt.return((entry, false));
      };

    switch (StringSet.mem(path, trusted^), M.get(path, files^)) {
    | (true, Some({exists: false, _})) => Lwt.fail(FileDoesNotExist(path))
    | (true, Some(entry)) =>
      if (entry.st_mtime != 0.0) {
        Lwt.return((entry, true));
      } else {
        read_stats();
      }
    | (_, None) => read_stats()
    | (false, Some(entry)) =>
      let%lwt ({exists, _} as entry, cached) = validate(path, entry);
      if (exists) {
        Lwt.return((entry, cached));
      } else {
        Lwt.fail(FileDoesNotExist(path));
      };
    };
  };

  let file_stat_opt = path => {
    let read_stats = () =>
      switch%lwt (FS.stat_option(path)) {
      | None =>
        update(path, no_file);
        Lwt.return_none;
      | Some({st_mtime, st_kind, _}) =>
        let entry = {...no_file, exists: true, st_mtime, st_kind};
        update(path, entry);
        Lwt.return_some((entry, false));
      };

    switch (StringSet.mem(path, trusted^), M.get(path, files^)) {
    | (true, Some({exists: false, _})) => Lwt.return_none
    | (true, Some(entry)) =>
      if (entry.st_mtime != 0.0) {
        Lwt.return_some((entry, true));
      } else {
        read_stats();
      }
    | (_, None) => read_stats()
    | (false, Some(entry)) =>
      let%lwt ({exists, _} as entry, cached) = validate(path, entry);
      if (exists) {
        Lwt.return_some((entry, cached));
      } else {
        Lwt.return_none;
      };
    };
  };

  let get_file = filename => {
    let read_file = () => {
      let%lwt stats = file_stat_opt(filename);
      switch (stats) {
      | Some((entry, _)) =>
        let%lwt entry =
          switch (entry.st_kind) {
          | Unix.S_REG =>
            let%lwt content = Lwt_io.(with_file(~mode=Input, filename, read));
            let digest = Digest.string(content);
            let entry = {...entry, content, digest};
            update(filename, entry);
            Lwt.return(entry);
          | _ => Lwt.return(entry)
          };

        Lwt.return((entry, false));
      | None => Lwt.fail(FileDoesNotExist(filename))
      };
    };

    switch (StringSet.mem(filename, trusted^), M.get(filename, files^)) {
    | (true, Some({exists: false, _})) =>
      Lwt.fail(FileDoesNotExist(filename))
    | (true, Some(entry)) =>
      if (entry.digest != "") {
        Lwt.return((entry, true));
      } else {
        read_file();
      }
    | (_, None) => read_file()
    | (false, Some(entry)) =>
      let%lwt ({exists, _} as entry, cached) = validate(filename, entry);
      if (exists) {
        Lwt.return((entry, cached));
      } else {
        Lwt.fail(FileDoesNotExist(filename));
      };
    };
  };

  let get_file_no_raise = filename => {
    let%lwt (entry, cached) =
      Lwt.catch(
        () => get_file(filename),
        fun
        | FileDoesNotExist(_) => {
            let entry = {
              exists: false,
              st_mtime: 0.0,
              st_kind: Unix.S_REG,
              content: "",
              digest: "",
              package: None,
            };
            update(filename, entry);
            Lwt.return((entry, false));
          }
        | exn => raise(exn),
      );

    Lwt.return((entry, cached));
  };

  let get_package = filename =>
    switch (StringSet.mem(filename, trusted^), M.get(filename, files^)) {
    | (true, Some({package: Some(package), _})) =>
      Lwt.return((package, true))
    | _ =>
      let%lwt (entry, cached) = get_file(filename);
      let package = Package.of_json(filename, entry.content);
      update(filename, {...entry, package: Some(package)});
      Lwt.return((package, cached));
    };

  let find_package_for_filename = (root_dir, filename) => {
    let rec find_package_json_for_filename = filename =>
      if (!FilePath.is_subdir(filename, root_dir)) {
        Lwt.return_none;
      } else {
        let dirname = FilePath.dirname(filename);
        let package_json = FilePath.concat(dirname, "package.json");
        if%lwt (file_exists(package_json)) {
          Lwt.return_some(package_json);
        } else {
          find_package_json_for_filename(dirname);
        };
      };

    switch%lwt (find_package_json_for_filename(filename)) {
    | Some(package_json) => get_package(package_json)
    | None => Lwt.return((Package.empty, false))
    };
  };

  let get_module = location => {
    let location_str = Module.location_to_string(location);
    let build_dependencies_changed = build_dependencies =>
      build_dependencies
      |> M.bindings
      |> Lwt_list.exists_s(((filename, known_digest)) => {
           let%lwt ({digest, _}, _) = get_file(filename);
           Lwt.return(digest != known_digest);
         });

    switch (M.get(location_str, modules^)) {
    | None => Lwt.return_none
    | Some({
        id,
        state,
        package,
        module_type,
        files,
        content,
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
          state,
          package,
          static_dependencies,
          dynamic_dependencies,
          build_dependencies,
          module_type,
          files,
          workspace: Workspace.of_string(content),
          scope,
          exports,
        })
      }
    };
  };

  let modify_content = (m: Module.t, content) =>
    switch (m.location) {
    | Module.EmptyModule
    | Module.Runtime => ()
    | _ =>
      let location_str = Module.location_to_string(m.location);
      let module_entry = {
        ModuleEntry.id: m.id,
        state: m.state,
        package: m.package,
        build_dependencies: m.build_dependencies,
        static_dependencies: m.static_dependencies,
        dynamic_dependencies: m.dynamic_dependencies,
        module_type: m.module_type,
        files: m.files,
        scope: m.scope,
        exports: m.exports,
        content,
      };

      modules := M.add(location_str, module_entry, modules^);
    };

  let remove = filename => trusted := StringSet.remove(filename, trusted^);

  let dump = () =>
    switch (init) {
    | Memory => Lwt.return_unit
    | Persistent(filename) =>
      Lwt_io.with_file(
        ~mode=Lwt_io.Output,
        ~perm=0o640,
        ~flags=Unix.[O_CREAT, O_TRUNC, O_RDWR],
        filename,
        ch =>
        Lwt_io.write_value(ch, ~flags=[], {files: files^, modules: modules^})
      )
    };

  Lwt.return({
    file_exists,
    file_stat,
    file_stat_opt,
    get_file,
    get_file_no_raise,
    get_package,
    find_package_for_filename,
    get_module,
    modify_content,
    remove,
    dump,
    starts_empty: files^ == M.empty,
  });
};
