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

- [ ] FastpackTraspiler: object spread, rest operators [zindel, in progress]
- [ ] FastpackTraspiler: decorators
- [ ] FastpackTraspiler: jsx
- [ ] FastpackTraspiler: flow - remove annotations
- [ ] CSS support in import statements (webpack ICSS)?
- [ ] Support external command execution for LESS/SASS/other processing
- [ ] Watch mode (watchman?)
- [ ] Source maps [andreypopp, in progress]
- [ ] UI/UX (error reporting, config)

### Heap

- [ ] support AST variable scope and check collisions with tmp_vars
- [ ] Think of Workspace.make_patcher API
- [ ] Think of integration with Flow

