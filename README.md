# fastpack

Pack JS code into a single bundle fast & easy.

## Development

Make sure you have opam environment activated and run:

    % make bootstrap

Then to produce the executable:

    % make build

To execute toplevel (OCaml REPL):

    % make top

## TODO

### MVP
- syntax: object spread, rest operators [zindel, in progress]
- syntax: decorators
- syntax: jsx
- syntax: flow - remove annotations
- CSS support in import statements (webpack ICSS)?
- support external command execution for LESS/SASS/other processing
- watch mode (watchman?)
- source maps [andreypopp, in progress]
- syntax error reporting

### Heap
- support AST variable scope and check collisions with tmp_vars;
- think of Workspace.make_patcher API;
- think of integration with Flow

