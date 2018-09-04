module M = Map.Make(String);
module StringSet = Set.Make(String);
module FS = FastpackUtil.FS;

type state =
  | Initial
  | Preprocessed
  | Analyzed;

[@deriving (show({with_path: false}), eq, ord)]
type file_location = {
  filename: option(string),
  preprocessors: list((string, string)),
};

[@deriving (show({with_path: false}), eq, ord)]
type location =
  | Main(list(string))
  | Runtime(string)
  | EmptyModule
  | File(file_location);

type module_type =
  | CJS
  | CJS_esModule
  | ESM;

let debug = Logs.debug;
/*
 * .js$ => <del>
 * / => $
 * node_modules => NM$
 * @ => AT$$
 * . => $$DOT$$
 * - => $$_$$
 * : => $$COLON$$
 * ! => $$B$$
 * ? => $$Q$$
 * = => $$E$$
 * */

let location_to_string = (~base_dir=None, location) => {
  let filename_to_string = filename =>
    switch (base_dir) {
    | None => filename
    | Some(base_dir) =>
      switch (filename.[0]) {
      | '/' => FS.relative_path(base_dir, filename)
      | _ => filename
      }
    };

  switch (location) {
  | Main(_) => "$fp$main"
  | EmptyModule => "$fp$empty"
  | Runtime(name) => "$fp$runtime__" ++ name
  | File({filename, preprocessors, _}) =>
    let preprocessors =
      preprocessors
      |> List.map(((p, opt)) => {
           let p = filename_to_string(p);
           if (opt != "") {
             p ++ "?" ++ opt;
           } else {
             p;
           };
         })
      |> String.concat("!");

    let filename =
      switch (filename) {
      | Some(filename) => filename_to_string(filename)
      | None => ""
      };

    if (preprocessors != "") {
      preprocessors ++ "!" ++ filename;
    } else {
      filename;
    };
  };
};

module CM = Map.Make(Char);

let allowed_chars =
  CM.empty
  |> CM.add('@', "AT$$")
  |> CM.add(':', "$$COLON$$")
  |> CM.add('.', "DOT$$")
  |> CM.add('-', "$$_$$")
  |> CM.add('/', "$")
  |> CM.add('=', "$$E$$")
  |> CM.add('?', "$$Q$$")
  |> CM.add('!', "$$B$$");

let make_id = (base_dir, location) =>
  switch (location) {
  | Main(_) => "$fp$main"
  | EmptyModule => "$fp$empty"
  | Runtime(name) => "$fp$runtime__" ++ name
  | File(_) =>
    let fix_chars = s => {
      let fix_char = c => {
        let code = Char.code(c);
        if (code >= 97
            && code <= 122  /* a - z */
            || code >= 65
            && code <= 90  /* A - Z */
            || code >= 48
            && code <= 57  /* 0 - 9*/
            || code == 36  /* $ */
            || code == 95) {
          /* _ */
          String.of_char(c);
        } else {
          switch (CM.get(c, allowed_chars)) {
          | Some(s) => s
          | None => Printf.sprintf("$$%d$$", code)
          };
        };
      };

      s
      |> String.to_array
      |> Array.to_list
      |> List.map(fix_char)
      |> String.concat("");
    };

    let to_var_name = s =>
      switch (s) {
      | "builtin" => "builtin"
      | _ =>
        let suf = ".js";
        String.(
          (
            if (suffix(~suf, s)) {
              sub(s, 0, length(s) - length(suf));
            } else {
              s;
            }
          )
          |> replace(~sub="node_modules", ~by="NM$")
          |> fix_chars
        );
      };

    location_to_string(~base_dir=Some(base_dir), location) |> to_var_name;
  };

let is_internal = request => {
  let internal_prefix = "$fp$";
  String.length(request) > String.length(internal_prefix)
  && String.sub(request, 0, String.length(internal_prefix))
  == internal_prefix;
};

let resolved_file2 = (~preprocessors=[], filename) => {
  let runtime_prefix = "$fp$runtime__";
  switch (filename) {
  | Some("$fp$empty") => EmptyModule
  | Some(name)
      when
        String.length(name) > String.length(runtime_prefix)
        && String.sub(name, 0, String.length(runtime_prefix))
        == runtime_prefix =>
    Runtime(
      String.sub(
        name,
        String.length(runtime_prefix),
        String.length(name) - String.length(runtime_prefix),
      ),
    )
  | _ => File({filename, preprocessors})
  };
};

let resolved_file = filename =>
  File({filename: Some(filename), preprocessors: []});

module Dependency = {
  type t = {
    /*** Original request to a dependency */
    request: string,
    /*** The filename this dependency was requested from */
    requested_from: location,
  };

  let compare = Pervasives.compare;

  let to_string = (~dir=None, {request, requested_from}) => {
    let requested_from =
      location_to_string(~base_dir=dir, requested_from)
      |> Printf.sprintf(" from module: %s");

    Printf.sprintf("'%s'%s", request, requested_from);
  };
};

module DependencyMap =
  Map.Make({
    type t = Dependency.t;
    let compare = Pervasives.compare;
  });

module LocationSet =
  Set.Make({
    let compare = compare_location;
    type t = location;
  });

type t = {
  /*** Opaque module id */
  id: string,
  /*** Absolute module filename */
  location,
  package: Package.t,
  /*** List of resolved static dependencies, populated for cached modules */
  static_dependencies: list((Dependency.t, location)),
  /*** List of resolved dynamic dependencies, populated for cached modules */
  dynamic_dependencies: list((Dependency.t, location)),
  /*** Mapping of filename to digest */
  build_dependencies: M.t(string),
  /*** If module is analyzed when packing */
  state,
  /*** CJS / CSJ with __esModule flag / EcmaScript */
  module_type,
  /*** "side-effect" files to be emitted alongside with module */
  files: list((string, string)),
  /*** Module source along with transformations applied */
  workspace: Workspace.t((t, DependencyMap.t(t))),
  /*** Module scope */
  scope: FastpackUtil.Scope.t,
  /*** Module exports */
  exports: FastpackUtil.Scope.exports,
};
