# fastpack

[![Build Status](https://travis-ci.org/fastpack/fastpack.svg?branch=master)](https://travis-ci.org/fastpack/fastpack)

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

- [x] FastpackTranspiler: jsx [andeypopp]
- [x] FastpackTranspiler: flow - remove annotations [zindel]
- [x] FastpackTranspiler: class syntax, properties, decorators [zindel]
- [x] Fastpack: Verify printer correctness (use babel-generator) [zindel]
- [x] Fastpack: JavaScript runtime - add require statement [zindel]
- [x] FastpackTranspiler: export statements [zindel]
- [x] Fastpack: import statements handling
- [x] FastpackTranspiler: object spread, rest operators [zindel]
- [x] RegularPacker: incremental builds
- [x] RegularPacker / FlatPacker: __es6Module flag
- [x] FlatPacker: turn dynamic dependency into static if needed
- [x] FlatPacker: add runtime
- [x] RegularPacker: `import` expressions should be Promises
- [x] FlatPacker: Support 'development', 'production', 'test' modes
- [x] Fastpack: use temporary file when writing the bundle
- [x] `--debug` writes to stderr (1)
- [x] FlatPacker : `--target [ app | es6 | cjs ]` for the last export statement
- [x] FlatPacker / RegularPacker: process.env.NODE_ENV is replaced with constant
- [x] FlatPacker / RegularPacker: set boolean `__DEV__` global based on mode
- [x] RegularPacker: add better API for cache (will enable watch mode later on)
- [x] FastpackTranspiler: spread operator in try/catch clause
- [x] FastpackTranspiler: add runtime

- [ ] UI/UX (error reporting, config) [zindel, in progress] (1)
- [ ] FlatPacker / RegularPacker: builtin modules?
- [ ] Configuration options in package.json (1?)
- [ ] Documentation / Domain (1)

- [ ] Use combinators for error output for nicer formatting? (2)
- [ ] Fastpack: handle static files (2)
- [ ] Fastpack: export URLs for static files (2)
- [ ] Support external command execution for LESS/SASS/other processing
- [ ] Source maps [andreypopp, in progress] (2)
- [ ] CSS support in import statements (webpack ICSS)? (2)
- [ ] FastpackTranspiler: PrivateName, PrivateField
- [ ] FastpackTranspiler: SpreadChild (2, in case we support something
  else than React)

### Heap

- [ ] Think of integration with Flow
- [ ] Implement rest operator for try/catch statements when flow parser suppots it
