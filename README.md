# fastpack

Pack JS code into a single bundle fast & easy.

## Development

Make sure you have `esy` installed:

    % npm install -g esy

Now install dependencies & build everything:

    % make bootstrap

Then to produce the executable:

    % make build

To run tests:

    % make test

To test compiled executables prepend with `esy x`:

    % esy x fpack

As merlin and others live inside sandboxed environment you'd want to execute
your editor from inside it:

    % esy vim
    % esy nvim
    % esy vscode
    % esy sublime

Alternatively you can enter into sandboxed shell:

    % esy shell

And execute commands from there.

## TODO

### MVP

- [x] FastpackTraspiler: jsx [andeypopp]
- [x] FastpackTraspiler: flow - remove annotations [zindel]
- [x] FastpackTraspiler: class syntax, properties, decorators [zindel]
- [x] Fastpack: Verify printer correctness (use babel-generator) [zindel]
- [x] Fastpack: JavaScript runtime - add require statement [zindel]
- [x] FastpackTranspiler: export statements [zindel]
- [x] Fastpack: import statements handling
- [x] FastpackTraspiler: object spread, rest operators [zindel]
- [x] Fastpack: `import` expressions
- [ ] FastpackTraspiler: JSXFragment, SpreadChild, PrivateName, PrivateField
- [ ] Fastpack: flat bundles
- [ ] Fastpack: Support 'development' & 'production' modes
- [ ] Fastpack: Partial builds
- [ ] Fastpack: handle static files
- [ ] Fastpack: export URLs for static files
- [ ] UI/UX (error reporting, config) [zindel, in progress]
  - [ ] Use combinators for error output for nicer formatting?
- [ ] Support external command execution for LESS/SASS/other processing
- [ ] Watch mode (watchman?)
- [ ] Source maps [andreypopp, in progress]
- [ ] CSS support in import statements (webpack ICSS)?
- [ ] Documentation / Domain

### Heap

- [x] FastpackTraspiler / patch model - how to process node by 2 different
      transpilers, i.e. spread operations and then remove flow type annotations
- [x] support AST variable scope and check collisions with tmp_vars
- [ ] Think of Workspace.make_patcher API
- [ ] Think of integration with Flow
- [ ] Implement rest operator for try/catch statements when flow parser suppots it
