module Loc = Flow_parser.Loc;
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

module Error = {
  let createElement = (~title, ~where=?, ~children, ()) =>
    Pastel.(
      <Pastel>
        {
          switch (where) {
          | None => ""
          | Some(where) => <Pastel bold=true color=Cyan> where "\n" </Pastel>
          }
        }
        <Pastel bold=true color=Red> title </Pastel>
        "\n"
        {String.concat("", children)}
      </Pastel>
    );
};

module CannotResolveModuleError = {
  let createElement = (~dep, ~children, ()) =>
    <Pastel>
      <Error
        where={
          Module.location_to_string(dep.Module.Dependency.requested_from)
        }
        title={
          Printf.sprintf("Cannot resolve '%s'", dep.Module.Dependency.request)
        }>
        children
      </Error>
    </Pastel>;
};

let formatErrorHeader = (~where="", text) =>
  <Pastel>
    <Pastel bold=true color=Red>where</Pastel>
    "\n"
    <Pastel color=Red>text</Pastel>
    "\n"
  </Pastel>

let get_codeframe = (loc: Loc.t, lines) => {
  let isTTY = FastpackUtil.FS.isatty(Unix.stderr);
  let startLine = max(0, loc.start.line - 2);
  let endLine = min(List.length(lines), loc._end.line + 1);
  let codeframe =
    CCList.filter_map(
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
        let lineNo = CCString.pad(maxDigits, string_of_int(i));
        switch (isErrorLine, isTTY) {
        | (false, _) => lineNo ++ " │ " ++ line
        | (true, false) =>
          let (offset, length) = (
            loc.start.column + 1,
            loc._end.column - loc.start.column,
          );
          let whitespaceBeforeBar = CCString.repeat(" ", maxDigits + 1);
          let whitespaceAfterBar = CCString.repeat(" ", offset);
          let carets = CCString.repeat("^", length);
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
          if (String.length(error_substring) > 0) {
            let colored_error = <Pastel color=Red>error_substring</Pastel>;
            Logs.debug(x =>
              x("e: %s ... colo: %s", error_substring, colored_error)
            );
            let colored_line =
              CCString.replace(~sub=error_substring, ~by=colored_error, line);

            <Pastel color=Red>lineNo</Pastel>
            ++ " │ "
            ++ colored_line;
          } else {
            line;
          };
        };
      },
      codeframe,
    );
  String.concat("\n", formatted);
};
type reason =
  | CannotLeavePackageDir(string)
  | CannotResolveModule(string, Module.Dependency.t)
  | CannotParseFile(
      string,
      list((Loc.t, Flow_parser.Parse_error.t)),
      string,
    )
  | NotImplemented(string)
  | CannotRenameModuleBinding(Loc.t, string, Module.Dependency.t)
  | CannotFindExportedName(string, string, string)
  | ScopeError(string, Scope.reason)
  | PreprocessorError(string, string)
  | UnhandledCondition(string, string);

let loc_to_string = ({Loc.start, _end, _}) =>
  Printf.sprintf(
    "(%d:%d) - (%d:%d):",
    start.line,
    start.column,
    _end.line,
    _end.column,
  );

let toString' = (package_dir, error) =>
  switch (error) {
  | UnhandledCondition(where, error) =>
    <Error where title="Preprocessor Error:"> error </Error>

  | CannotLeavePackageDir(filename) =>
    Printf.sprintf("%s is out of the working directory\n", filename)

  /* TODO: rework this a little */
  | CannotResolveModule(msg, dep) =>
    let header =
      formatErrorHeader(
        ~where=Module.location_to_string(dep.requested_from),
        "Cannot resolve '" ++ dep.request ++ "'",
      );

    switch (List.assoc_opt(dep.request, nodelibs)) {
    | None => String.concat("\n", [header, msg])
    | Some(None) =>
      String.concat(
        "\n",
        [
          header,
          {|
This looks like base node.js library which does not have any browser
implementation we are aware of
          |},
        ],
      )
    | Some(Some(mock)) =>
      let msg =
        [
          header,
          {|
This looks like base node.js library and unlikely is required in the
browser environment.
If you still want to use it, first install the browser implementation with:
          |},
          Printf.sprintf("\t\tnpm install --save %s", mock),
        ]
        @ (
          if (mock != dep.request) {
            [
              "",
              "And then add this command line option when running fastpack:",
              "",
              Printf.sprintf("\t\t--mock %s:%s", dep.request, mock),
            ];
          } else {
            [];
          }
        );

      String.concat("\n", msg);
    };

  | CannotParseFile(where, errors, source) =>
    let lines =
      String.split_on_char('\n', source)
      |> List.mapi((i, line) => (i + 1, line));

    String.concat(
      "\n",
      [
        formatErrorHeader(~where, "Parse error"),
        String.concat(
          "\n",
          List.map(
            ((loc, error)) => {
              let error_desc = Flow_parser.Parse_error.PP.error(error);
              String.concat(
                "\n",
                [
                  "--------------------",
                  error_desc ++ " at " ++ loc_to_string(loc),
                  "",
                  get_codeframe(loc, lines),
                  "",
                ],
              );
            },
            CCList.take(2, errors),
          ),
        ),
        "",
      ],
    );

  | NotImplemented(message) =>
    String.concat("\n", [formatErrorHeader("Not Implemented"), message])

  | CannotRenameModuleBinding(loc, id, dep) =>
    Printf.sprintf(
      "Cannot rename module binding:\n%s %s\nImport Request: %s\nTypically, it means that you are trying to use the name before importing it in\nthe code.\n",
      loc_to_string(loc),
      id,
      Module.Dependency.to_string(~dir=Some(package_dir), dep),
    )

  | CannotFindExportedName(where, name, location_str) =>
    String.concat(
      "\n",
      [
        formatErrorHeader(~where, "Import Error"),
        Printf.sprintf(
          "Cannot import name '%s' from '%s'\n",
          name,
          location_str,
        ),
      ],
    )

  | ScopeError(where, reason) =>
    String.concat(
      "\n",
      [
        formatErrorHeader(~where, "Module Scope Error:"),
        Scope.error_to_string(reason),
      ],
    )

  | PreprocessorError(where, error) =>
    String.concat(
      "\n",
      [formatErrorHeader(~where, "Preprocessor Error:"), error],
    )
  };

let toString = (current_dir, error) =>
  Printf.sprintf("\n%s\n", toString'(current_dir, error));

let ie = FastpackUtil.Error.ie;

exception PackError(reason);
exception ExitError(string);
exception ExitOK;
