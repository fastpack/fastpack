module FS = FastpackUtil.FS;
module M = Map.Make(String);

module Mock = {
  type t =
    | Empty
    | Mock(string);

  let to_string = mock =>
    switch (mock) {
    | Empty => ""
    | Mock(mock) => mock
    };

  let parse = s =>
    switch (String.(s |> trim |> split_on_char(':'))) {
    | []
    | [""] => Result.Error(`Msg("Empty config"))
    | [request]
    | [request, ""] => Result.Ok((false, (request, Empty)))
    | [request, ...rest] =>
      let mock = String.concat(":", rest);
      Result.Ok((false, (request, Mock(mock))));
    };

  let print = (ppf, (_, mock)) => {
    let value =
      switch (mock) {
      | (request, Empty) => request
      | (request, Mock(mock)) => request ++ ":" ++ mock
      };

    Format.fprintf(ppf, "%s", value);
  };
};

type t = {
  resolve:
    (~basedir: string, string) => Lwt.t((Module.location, list(string))),
};

exception Error(string);

[@deriving ord]
type request =
  | PathRequest(string)
  | PackageRequest((string, option(string)))
  | InternalRequest(string);

module RequestMap =
  Map.Make({
    type t = request;
    let compare = compare_request;
  });

module RequestSet =
  Set.Make({
    type t = request;
    let compare = compare_request;
  });

let request_to_string = req =>
  switch (req) {
  | InternalRequest(s) => s
  | PathRequest(s) => s
  | PackageRequest((pkg, path)) =>
    pkg
    ++ (
      switch (path) {
      | None => ""
      | Some(path) => "/" ++ path
      }
    )
  };

let make =
    (
      ~project_root: string,
      ~current_dir: string,
      ~mock: list((string, Mock.t)),
      ~node_modules_paths: list(string),
      ~extensions: list(string),
      ~preprocessor: Preprocessor.t,
      ~cache: Cache.t,
    ) => {
  let normalize_request = (~basedir: string, request) =>
    Run.Syntax.(
      if (Module.is_internal(request)) {
        return(InternalRequest(request));
      } else {
        switch (request) {
        | "" => error("Empty request")
        | _ =>
          switch (request.[0]) {
          | '.' => return(PathRequest(FS.abs_path(basedir, request)))
          | '/' => return(PathRequest(request))
          | '@' =>
            switch (String.split_on_char('/', request)) {
            | []
            | [_] =>
              error(Printf.sprintf("Bad scoped package name: %s", request))
            | [scope, package] =>
              return(PackageRequest((scope ++ "/" ++ package, None)))
            | [scope, package, ...rest] =>
              return(
                PackageRequest((
                  scope ++ "/" ++ package,
                  Some(String.concat("/", rest)),
                )),
              )
            }
          | _ =>
            switch (String.split_on_char('/', request)) {
            | [] => error("Bad package request")
            | [package] => return(PackageRequest((package, None)))
            | [package, ...rest] =>
              return(
                PackageRequest((package, Some(String.concat("/", rest)))),
              )
            }
          }
        };
      }
    );

  let mock_map = {
    let build_mock_map = () =>
      Run.Syntax.(
        Run.foldLeft(
          ~f=
            (acc, (k, v)) => {
              let%bind normalized_key =
                normalize_request(~basedir=current_dir, k);
              let%bind normalized_value =
                switch (v) {
                | Mock.Empty => return(InternalRequest("$fp$empty"))
                | Mock.Mock(v) => normalize_request(~basedir=current_dir, v)
                };

              switch (normalized_key, normalized_value) {
              | (InternalRequest(_), _) =>
                error("Cannot mock internal package: " ++ k)
              | (PackageRequest((_, Some(_))), _) =>
                error("Cannot mock path inside the package: " ++ k)
              | (PathRequest(_), PackageRequest(_)) =>
                error(
                  "File could be only mocked with another file, not package: "
                  ++ k
                  ++ ":"
                  ++ Mock.to_string(v),
                )
              | _ =>
                return(RequestMap.add(normalized_key, normalized_value, acc))
              };
            },
          ~init=RequestMap.empty,
          mock,
        )
      );

    switch (build_mock_map()) {
    | Ok(mock_map) => mock_map
    | Error(error) => raise(Error(Run.formatError(error)))
    };
  };

  let resolve_mock = normalized_request =>
    RequestMap.get(normalized_request, mock_map);

  let package_json_cache = ref(M.empty);
  let rec find_package = dir =>
    switch (M.get(dir, package_json_cache^)) {
    | Some(package) => Lwt.return(package)
    | None =>
      let filename = FilePath.concat(dir, "package.json");
      switch%lwt (cache.file_exists(filename)) {
      | true =>
        let%lwt (package, _) = cache.get_package(filename);
        package_json_cache := M.add(dir, package, package_json_cache^);
        Lwt.return(package);
      | false =>
        if (dir == current_dir) {
          Lwt.return(Package.empty);
        } else {
          let%lwt package = find_package(FilePath.dirname(dir));
          package_json_cache := M.add(dir, package, package_json_cache^);
          Lwt.return(package);
        }
      };
    };

  let rec resolve_file = (~try_directory=true, path) => {
    open RunAsync.Syntax;
    let rec resolve' = extensions =>
      switch (extensions) {
      | [] =>
        if (try_directory) {
          resolve_directory(path);
        } else {
          error("Cannot resolve module");
        }
      | [ext, ...rest] =>
        let filename = path ++ ext;
        let context = Printf.sprintf("File exists? '%s'", filename);
        RunAsync.(
          withContext(
            context,
            switch%lwt (cache.file_stat_opt(filename)) {
            | Some(({st_kind: Lwt_unix.S_REG, _}, _)) => return(filename)
            | _ => withContext("...no.", resolve'(rest))
            },
          )
        );
      };

    resolve'(["", ...extensions]);
  }
  and resolve_directory = path => {
    let context = Printf.sprintf("Is directory? '%s'", path);

    RunAsync.(
      withContext(
        context,
        switch%lwt (cache.file_stat_opt(path)) {
        | Some(({st_kind: Lwt_unix.S_DIR, _}, _)) =>
          withContext(
            "...yes.",
            {
              let package_json = FilePath.concat(path, "package.json");
              switch%lwt (cache.file_stat_opt(package_json)) {
              | Some(({st_kind: Lwt_unix.S_REG, _}, _)) =>
                let%lwt ({Package.entry_point, _}, _) =
                  cache.get_package(package_json);
                resolve_file(FS.abs_path(path, entry_point));
              | _ => resolve_file(~try_directory=false, path ++ "/index")
              };
            },
          )
        | _ => withContext("...no.", error("Cannot resolve module"))
        },
      )
    );
  };

  let find_package_path_in_node_modules = (~basedir, package_name) => {
    let try_paths =
      node_modules_paths
      |> List.map(node_modules_path =>
           switch (node_modules_path.[0]) {
           | '/' => [FilePath.concat(node_modules_path, package_name)]
           | _ =>
             let rec gen_paths = dir => {
               let package_path =
                 FilePath.concat(
                   FilePath.concat(dir, node_modules_path),
                   package_name,
                 );

               if (dir == project_root) {
                 [package_path];
               } else {
                 [package_path, ...FilePath.dirname(dir) |> gen_paths];
               };
             };

             gen_paths(basedir);
           }
         )
      |> List.concat;

    open RunAsync.Syntax;
    let rec exists' = paths =>
      switch (paths) {
      | [] => error("Cannot find package path")
      | [path, ...rest] =>
        let context = Printf.sprintf("Path exists? '%s'", path);
        RunAsync.(
          withContext(
            context,
            switch%lwt (cache.file_stat_opt(path)) {
            | Some(({st_kind: Lwt_unix.S_DIR, _}, _)) => return(path)
            | _ => withContext("...no.", exists'(rest))
            },
          )
        );
      };

    exists'(try_paths);
  };

  let withDependencies = (dependencies, resolved) =>
    switch%lwt (resolved) {
    | Ok((resolved, resolved_dependencies)) =>
      Lwt.return_ok((resolved, dependencies @ resolved_dependencies))
    | Error(err) => Lwt.return_error(err)
    };

  let withPackageDependency = (package, resolved) =>
    switch (package.Package.filename) {
    | None => resolved
    | Some(filename) => withDependencies([filename], resolved)
    };

  let rec resolve_simple_request = (~seen=RequestSet.empty, ~basedir, request) => {
    open RunAsync.Syntax;
    let%bind normalized_request =
      RunAsync.liftOfRun(normalize_request(~basedir, request));

    RequestSet.mem(normalized_request, seen) ?
      error("Resolver went into cycle") :
      {
        let seen = RequestSet.add(normalized_request, seen);
        let context =
          Printf.sprintf(
            "Resolving '%s'.",
            request_to_string(normalized_request),
          );

        RunAsync.(
          withContext(
            context,
            switch (normalized_request) {
            | InternalRequest(request) => return((request, []))
            | PathRequest(request) =>
              let%bind resolved = resolve_file(request);
              let%lwt package = find_package(FilePath.dirname(resolved));
              let context =
                Printf.sprintf(
                  "Resolving '%s' through \"browser\"",
                  resolved,
                );

              withPackageDependency(
                package,
                withContext(
                  context,
                  switch (Package.resolve_browser(package, resolved)) {
                  | Some(Package.Ignore) => return(("$fp$empty", []))
                  | Some(Package.Shim(shim)) =>
                    withContext(
                      Printf.sprintf("...found '%s'.", shim),
                      resolve_simple_request(
                        ~seen,
                        ~basedir=FilePath.dirname(resolved),
                        shim,
                      ),
                    )
                  | None =>
                    withContext(
                      "...not found.",
                      withContext(
                        "Mocked file?",
                        switch (resolve_mock(PathRequest(resolved))) {
                        | Some(PathRequest(path)) =>
                          withContext(
                            Printf.sprintf("...yes. '%s'", path),
                            switch%lwt (cache.file_stat_opt(path)) {
                            | Some(({st_kind: Lwt_unix.S_REG, _}, _)) =>
                              return((path, []))
                            | _ => error("File not found: " ++ path)
                            },
                          )
                        | Some(InternalRequest(request)) =>
                          return((request, []))
                        | Some(_) => error("Incorrect mock configuration")
                        | None => return((resolved, []))
                        },
                      ),
                    )
                  },
                ),
              );
            | PackageRequest((package_name, path)) =>
              withContext(
                "Mocked package?",
                switch (resolve_mock(PackageRequest((package_name, None)))) {
                | Some(InternalRequest(resolved)) => return((resolved, []))
                | Some(PathRequest(request) as r) =>
                  let request =
                    request
                    ++ (
                      switch (path) {
                      | None => ""
                      | Some(path) => "/" ++ path
                      }
                    );

                  withContext(
                    Printf.sprintf("...yes '%s'.", request_to_string(r)),
                    resolve_simple_request(~seen, ~basedir, request),
                  );
                | Some(PackageRequest((package_name, mocked_path)) as r) =>
                  let request =
                    package_name
                    ++ (
                      switch (mocked_path) {
                      | None => ""
                      | Some(path) => "/" ++ path
                      }
                    )
                    ++ (
                      switch (path) {
                      | None => ""
                      | Some(path) => "/" ++ path
                      }
                    );

                  withContext(
                    Printf.sprintf("...yes '%s'.", request_to_string(r)),
                    resolve_simple_request(~seen, ~basedir, request),
                  );
                | None =>
                  withContext(
                    "...no.",
                    {
                      let%lwt package = find_package(basedir);
                      withPackageDependency(
                        package,
                        {
                          let context =
                            Printf.sprintf(
                              "Resolving '%s' through \"browser\"",
                              package_name,
                            );

                          withContext(
                            context,
                            switch (
                              Package.resolve_browser(package, package_name)
                            ) {
                            | Some(Package.Ignore) =>
                              return(("$fp$empty", []))
                            | Some(Package.Shim(shim)) =>
                              /* TODO: what if path is not None?*/
                              withContext(
                                Printf.sprintf("...found '%s'.", shim),
                                resolve_simple_request(~seen, ~basedir, shim),
                              )
                            | None =>
                              withContext(
                                "...not found.",
                                {
                                  let%bind package_path =
                                    withContext(
                                      "Resolving package path",
                                      find_package_path_in_node_modules(
                                        ~basedir,
                                        package_name,
                                      ),
                                    );

                                  let request =
                                    package_path
                                    ++ (
                                      switch (path) {
                                      | None => ""
                                      | Some(path) => "/" ++ path
                                      }
                                    );

                                  resolve_simple_request(
                                    ~seen,
                                    ~basedir,
                                    request,
                                  );
                                },
                              )
                            },
                          );
                        },
                      );
                    },
                  )
                },
              )
            },
          )
        );
      };
  };

  let resolve_preprocessor = (~basedir, preprocessor) =>
    RunAsync.Syntax.(
      switch (preprocessor) {
      | "builtin" => return((("builtin", ""), []))
      | _ =>
        let context =
          Printf.sprintf(
            "Resolving preprocessor '%s', base directory '%s'",
            preprocessor,
            basedir,
          );

        RunAsync.withContext(
          context,
          {
            let%bind (request, options) =
              switch (String.split_on_char('?', preprocessor)) {
              | [] => error("Empty request")
              | [request] => return((request, ""))
              | [request, ...options] =>
                return((request, String.concat("?", options)))
              };

            let%bind (resolved, dependencies) =
              resolve_simple_request(~basedir, request);

            return(((resolved, options), dependencies));
          },
        );
      }
    );

  let resolve = (~basedir, request) => {
    let resolve' = () => {
      open RunAsync.Syntax;
      let (parts, preprocess) = {
        let rec to_parts = (~preprocess=true) =>
          fun
          | [] => ([], false)
          | ["-", ...rest]
          | ["", "", ...rest]
          | ["", ...rest] => to_parts(~preprocess=false, rest)
          | parts => (parts, preprocess);

        to_parts(String.split_on_char('!', request));
      };

      switch (List.rev(parts)) {
      | [] => error("Empty request")
      | [filename, ...preprocessors] =>
        let resolve_preprocessors = preprocessors => {
          let rec resolve_preprocessors' = (
            fun
            | [] => return(([], []))
            | [request, ...rest] => {
                let%bind (resolved, dependencies) =
                  resolve_preprocessor(~basedir, request);

                let%bind (all_resolved, dependencies) =
                  withDependencies(
                    dependencies,
                    resolve_preprocessors'(rest),
                  );

                return(([resolved, ...all_resolved], dependencies));
              }
          );

          let context =
            Printf.sprintf(
              "Resolving preprocessors '%s'",
              String.concat("!", preprocessors),
            );

          RunAsync.withContext(
            context,
            resolve_preprocessors'(preprocessors),
          );
        };

        switch (filename) {
        | "" =>
          let%bind (preprocessors, dependencies) =
            resolve_preprocessors(preprocessors);
          return((None, dependencies, List.rev(preprocessors)));
        | _ =>
          let%bind (resolved, dependencies) =
            resolve_simple_request(~basedir, filename);

          let configured_preprocessors =
            preprocess ? preprocessor.get_processors(resolved) : [];

          let%bind (preprocessors, dependencies) =
            withDependencies(
              dependencies,
              resolve_preprocessors(
                List.rev(configured_preprocessors) @ List.rev(preprocessors),
              ),
            );

          return((Some(resolved), dependencies, preprocessors));
        };
      };
    };

    let context =
      Printf.sprintf(
        "Resolving '%s'. Base directory: '%s'",
        request,
        basedir,
      );

    switch%lwt (RunAsync.(withContext(context, resolve'()))) {
    | Ok((filename, dependencies, preprocessors)) =>
      let location = Module.resolved_file2(~preprocessors, filename);
      Lwt.return((location, dependencies));
    | Error(error) => Lwt.fail(Error(Run.formatError(error)))
    };
  };

  {resolve: resolve};
};
