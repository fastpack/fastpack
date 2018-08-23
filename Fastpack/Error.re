module Loc = FlowParser.Loc;
module Scope = FastpackUtil.Scope;

/*
   assoc list of nodejs libs and their browser implementations
   as listed on: https://github.com/webpack/node-libs-browser
 */
let nodelibs = [
  ("assert", Some("assert")),
  ("buffer", Some("buffer")),
  ("child_process", None),
  ("cluster", None),
  ("console", Some("console-browserify")),
  ("constants", Some("constants-browserify")),
  ("crypto", Some("crypto-browserify")),
  ("dgram", None),
  ("dns", None),
  ("domain", Some("domain-browser")),
  ("events", Some("events")),
  ("fs", None),
  ("http", Some("stream-http")),
  ("https", Some("https-browserify")),
  ("module", None),
  ("net", None),
  ("os", Some("os-browserify")),
  ("path", Some("path-browserify")),
  ("process", Some("process")),
  ("punycode", Some("punycode")),
  ("querystring", Some("querystring-es3")),
  ("readline", None),
  ("repl", None),
  ("stream", Some("stream-browserify")),
  ("string_decoder", Some("string_decoder")),
  ("sys", Some("util")),
  ("timers", Some("timers-browserify")),
  ("tls", None),
  ("tty", Some("tty-browserify")),
  ("url", Some("url")),
  ("util", Some("util")),
  ("vm", Some("vm-browserify")),
  ("zlib", Some("browserify-zlib")),
];

type color =
  | Cyan
  | Red
  | Black
  | White;
type font =
  | Regular
  | Bold;

let print_with_color = (~font=Regular, ~isTTY=true, str, col) => {
  let col =
    switch (col) {
    | Cyan => "36"
    | Red => "31"
    | Black => "30"
    | White => "37"
    };

  let f =
    switch (font) {
    | Regular => "0"
    | Bold => "1"
    };

  if (isTTY) {
    "\027[" ++ f ++ ";" ++ col ++ "m" ++ str ++ "\027[0m";
  } else {
    str;
  };
};

let format_error_header = (~isTTY=true, ~subtitle="", (title, path)) =>
  if (isTTY) {
    (
      print_with_color(title, Red) ++ " " ++ subtitle,
      print_with_color(~font=Bold, path, Cyan),
    );
  } else {
    (title ++ " " ++ subtitle, path);
  };

let get_codeframe = (~isTTY=false, loc: Loc.t, lines) => {
  let startLine = max(0, loc.start.line - 2);
  let endLine = min(List.length(lines), loc._end.line + 1);
  let codeframe =
    List.filter_map(
      ((i, line)) =>
        if (startLine <= i && i <= endLine) {
          Some((i, line));
        } else {
          None;
        },
      lines,
    );

  let maxLineNo = List.fold_left((n, (i, _)) => max(n, i), 0, lines);
  let maxDigits = String.length(string_of_int(maxLineNo));
  let formatted =
    List.map(
      ((i, line)) => {
        let isErrorLine = loc.start.line <= i && i <= loc._end.line;
        let lineNo = String.pad(maxDigits, string_of_int(i));
        switch (isErrorLine, isTTY) {
        | (false, _) => lineNo ++ " │ " ++ line
        | (true, false) =>
          let (offset, length) = (
            loc.start.column + 1,
            loc._end.column - loc.start.column,
          );
          let whitespaceBeforeBar = String.repeat(" ", maxDigits + 1);
          let whitespaceAfterBar = String.repeat(" ", offset);
          let carets = String.repeat("^", length);
          lineNo
          ++ " │ "
          ++ line
          ++ "\n"
          ++ whitespaceBeforeBar
          ++ "│"
          ++ whitespaceAfterBar
          ++ carets;
        | (true, true) =>
          let error_substring =
            FastpackUtil.UTF8.sub(
              line,
              loc.start.column,
              loc._end.column - loc.start.column,
            );
          let colored_error = print_with_color(error_substring, Red);
          let colored_line =
            String.replace(~sub=error_substring, ~by=colored_error, line);
          print_with_color(lineNo, Red) ++ " │ " ++ colored_line;
        };
      },
      codeframe,
    );
  String.concat("\n", formatted);
};
type reason =
  | CannotReadModule(string)
  | CannotLeavePackageDir(string)
  | CannotResolveModule(string, Module.Dependency.t)
  | CannotParseFile(
      (string, list((Loc.t, FlowParser.Parse_error.t)), string),
    )
  | NotImplemented(option(Loc.t), string)
  | CannotRenameModuleBinding(Loc.t, string, Module.Dependency.t)
  | DependencyCycle(list(string))
  | CannotFindExportedName(string, string)
  | ScopeError(Scope.reason)
  | PreprocessorError(string)
  | UnhandledCondition(string)
  | CliArgumentError(string);

let loc_to_string = ({Loc.start, _end, _}) =>
  Printf.sprintf(
    "(%d:%d) - (%d:%d):",
    start.line,
    start.column,
    _end.line,
    _end.column,
  );

let to_string = (package_dir, error) =>
  switch (error) {
  | UnhandledCondition(message) => message

  | CliArgumentError(message) => "CLI argument error: " ++ message

  | CannotReadModule(filename) => "Cannot read file: " ++ filename

  | CannotLeavePackageDir(filename) =>
    Printf.sprintf("%s is out of the working directory\n", filename)

  /* TODO: rework this a little */
  | CannotResolveModule(msg, dep) =>
    let isTTY = FastpackUtil.FS.isatty(Unix.stderr);
    let (error_title, error_path) =
      format_error_header(
        ~isTTY,
        ~subtitle="cannot resolve '" ++ dep.request ++ "'",
        (
          "Module resolution error:",
          Module.location_to_string(dep.requested_from),
        ),
      );

    switch (List.assoc_opt(dep.request, nodelibs)) {
    | None => String.concat("\n", [error_title, error_path, msg])
    | Some(None) =>
      String.concat(
        "\n",
        [
          error_title,
          error_path,
          "This looks like base node.js library which does not have any browser implementation we are aware of",
        ],
      )
    | Some(Some(mock)) =>
      String.concat(
        "\n",
        [
          error_title,
          error_path,
          "This looks like base node.js library and unlikely is required in the browser environment.",
          "If you still want to use it, first install the browser implementation with:",
          "",
          Printf.sprintf("\t\tnpm install --save %s", mock),
          "",
          "And then add this command line option when running fpack:",
          "",
          Printf.sprintf("\t\t--mock %s:%s", dep.request, mock),
        ],
      )
    };

  | CannotParseFile((location_str, errors, source)) =>
    let isTTY = FastpackUtil.FS.isatty(Unix.stderr);
    let lines =
      String.split_on_char('\n', source)
      |> List.mapi((i, line) => (i + 1, line));

    let format_error = (isTTY, (loc, error)) => {
      let error_desc = FlowParser.Parse_error.PP.error(error);
      String.concat(
        "\n",
        [
          "--------------------",
          error_desc ++ " at " ++ loc_to_string(loc),
          "",
          get_codeframe(~isTTY, loc, lines),
          "",
        ],
      );
    };

    let (error_title, error_path) =
      format_error_header(~isTTY, ("Parse error", location_str));
    String.concat(
      "\n",
      [
        error_title,
        error_path,
        "",
        String.concat("\n", List.map(format_error(isTTY), errors)),
        "",
      ],
    );

  | NotImplemented(some_loc, message) =>
    let loc =
      switch (some_loc) {
      | Some(loc) => loc_to_string(loc) ++ " "
      | None => ""
      };

    loc ++ message;

  | CannotRenameModuleBinding(loc, id, dep) =>
    Printf.sprintf(
      "Cannot rename module binding:\n%s %s\nImport Request: %s\nTypically, it means that you are trying to use the name before importing it in\nthe code.\n",
      loc_to_string(loc),
      id,
      Module.Dependency.to_string(~dir=Some(package_dir), dep),
    )

  | DependencyCycle(filenames) =>
    Printf.sprintf("Dependency cycle detected:\n\t%s\n") @@
    String.concat("\n\t") @@
    List.map(
      filename => String.replace(~sub=package_dir ++ "/", ~by="", filename),
      filenames,
    )

  | CannotFindExportedName(name, location_str) =>
    Printf.sprintf(
      "Cannot find exported name '%s' in module '%s'\n",
      name,
      location_str,
    )

  | ScopeError(reason) => Scope.error_to_string(reason)

  | PreprocessorError(error) => error
  };

let ie = FastpackUtil.Error.ie;
