module M = Map.Make(String);

type t = {
  filename: option(string),
  entry_point: string,
  browser_shim: M.t(browser_shim),
}
and browser_shim =
  | Shim(string)
  | Ignore;

let empty = {filename: None, entry_point: "index.js", browser_shim: M.empty};

let normalize = (~package_json_filename, path) =>
  if (path.[0] === '.') {
    FastpackUtil.FS.abs_path(FilePath.dirname(package_json_filename), path);
  } else {
    path;
  };

let of_json = (filename, data) => {
  let data = Yojson.Safe.from_string(String.trim(data));
  Yojson.Safe.Util.(
    try (
      {
        let main = member("main", data) |> to_string_option;
        let module_ = member("module", data) |> to_string_option;
        let (browser, browser_shim) = {
          let field = member("browser", data);
          switch (field) {
          | `Assoc(items) =>
            let f = (browser_shim, (key, v)) => {
              let key = normalize(~package_json_filename=filename, key);
              switch (v) {
              | `String(shim) =>
                let shim = normalize(~package_json_filename=filename, shim);
                M.add(key, Shim(shim), browser_shim);
              | `Bool(false) => M.add(key, Ignore, browser_shim)
              | _ => browser_shim
              };
            };

            let browser_shim = ListLabels.fold_left(~init=M.empty, ~f, items);
            (None, browser_shim);
          | `String(browser) => (Some(browser), M.empty)
          | _ =>
            /* TODO: differentiate between absent field and invalid type */
            (None, M.empty)
          };
        };

        let entry_point =
          switch (browser, module_, main) {
          | (Some(browser), _, _) => "./" ++ browser
          | (None, Some(module_), _) => "./" ++ module_
          | (None, None, Some(main)) => "./" ++ main
          | (None, None, None) => "index.js"
          };

        /* TODO: shouldn't this be in Resolver? */
        let entry_point =
          switch (
            M.get(
              normalize(~package_json_filename=filename, entry_point),
              browser_shim,
            )
          ) {
          | Some(Shim(shim)) => shim
          | Some(Ignore) => "$fp$empty"
          | None => entry_point
          };

        {filename: Some(filename), entry_point, browser_shim};
      }
    ) {
    | Type_error(_) => {
        filename: None,
        entry_point: "index.js",
        browser_shim: M.empty,
      }
    }
  );
};
/* TODO: provide better report here */
/* failwith ("Package.json cannot be parsed: " ^ filename) */

let resolve_browser = (package: t, path: string) =>
  switch (package) {
  | {filename: None, _} => None
  | {filename: Some(filename), browser_shim, _} =>
    let path = normalize(~package_json_filename=filename, path);
    M.get(path, browser_shim);
  };
