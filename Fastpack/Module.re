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
  | Runtime
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

let location_to_short_string = (~base_dir=None, location) => {
  let filename_to_string = filename =>
    switch (base_dir) {
    | None => filename
    | Some(base_dir) => FS.relative_path(base_dir, filename)
    };

  switch (location) {
  | Main(_) => "main"
  | EmptyModule => "empty"
  | Runtime => "transpiler-runtime"
  | File({filename: Some(filename), _}) => filename_to_string(filename)
  | File({filename: None, _}) => "no filename"
  };
};

let location_to_string = (~base_dir=None, location) => {
  let filename_to_string = filename =>
    switch (base_dir) {
    | None => filename
    | Some(base_dir) => FS.relative_path(base_dir, filename)
    };

  switch (location) {
  | Main(_) => "$fp$main"
  | EmptyModule => "$fp$empty"
  | Runtime => "$fp$runtime"
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

module CM = CCMap.Make(CCChar);

let allowed_chars =
  CM.empty
  |> CM.add('@', "AT$$")
  |> CM.add(':', "$$COLON$$")
  |> CM.add('.', "DOT$$")
  |> CM.add('-', "$$_$$")
  |> CM.add('/', "$")
  |> CM.add('\\', "$")
  |> CM.add('=', "$$E$$")
  |> CM.add('?', "$$Q$$")
  |> CM.add('!', "$$B$$");

let make_id = (base_dir, location) =>
  switch (location) {
  | Main(_) => "$fp$main"
  | EmptyModule => "$fp$empty"
  | Runtime => "$fp$runtime"
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
          CCString.of_char(c);
        } else {
          switch (CM.get(c, allowed_chars)) {
          | Some(s) => s
          | None => Printf.sprintf("$$%d$$", code)
          };
        };
      };

      s
      |> CCString.to_array
      |> Array.to_list
      |> List.map(fix_char)
      |> String.concat("");
    };

    let to_var_name = s =>
      switch (s) {
      | "builtin" => "builtin"
      | _ =>
        let suf = ".js";
        CCString.(
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

let is_internal = request =>
  request == "$fp$empty" || request == "$fp$runtime" || request == "$fp$main";

let resolved_file2 = (~preprocessors=[], filename) =>
  switch (filename) {
  | Some("$fp$empty") => EmptyModule
  | Some("$fp$runtime") => Runtime
  | _ => File({filename, preprocessors})
  };

let resolved_file = filename =>
  File({filename: Some(filename), preprocessors: []});

module Dependency = {
  type t = {
    /*** Original request to a dependency */
    request: string,
    /*** Request to a dependency as it appears in the resulting bundle */
    encodedRequest: string,
    /*** The filename this dependency was requested from */
    requested_from: location,
  };

  let compare = (d1: t, d2: t) =>
    Pervasives.compare(
      (d1.request, d1.requested_from),
      (d2.request, d2.requested_from),
    );

  let to_string = (~dir=None, {request, requested_from, _}) => {
    let requested_from =
      location_to_string(~base_dir=dir, requested_from)
      |> Printf.sprintf(" from module: %s");

    Printf.sprintf("'%s'%s", request, requested_from);
  };
};

module DependencyMap =
  CCMap.Make({
    type t = Dependency.t;
    let compare = Dependency.compare;
  });

module LocationSet =
  Set.Make({
    let compare = compare_location;
    type t = location;
  });

module LocationMap =
  CCMap.Make({
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
  build_dependencies: M.t(float),
  /*** CJS / CSJ with __esModule flag / EcmaScript */
  module_type,
  /*** "side-effect" files to be emitted alongside with module */
  files: list((string, string)),
  /*** Module source along with transformations applied */
  source: string,
  /*** Module scope */
  scope: FastpackUtil.Scope.t,
  /*** Module exports */
  exports: FastpackUtil.Scope.exports,
  /*** Warnings collected from preprocessors */
  warnings: list(string),
};

type m = t;
module Set =
  Set.Make({
    type t = m;
    let compare = (m1, m2) => compare_location(m1.location, m2.location);
  });
