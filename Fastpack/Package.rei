/**
 * Read package.json files
 * Currently considered fields are: "browser", "module", and "main".
 * */;

type t = {
  filename: option(string),
  entry_point: string,
  browser_shim: CCMap.Make(CCString).t(browser_shim),
}
and browser_shim =
  | Shim(string)
  | Ignore;

/** Construct empty package.json representation. */

let empty: t;

/**
 * Construct package.json based on exisiting file.
 * `of_json filename data` where `data` is the raw content of the file
 * */

let of_json: (string, string) => t;

/**
 * Resolve dependncy request through "browser" field.
 */

let resolve_browser: (t, string) => option(browser_shim);
