## TODO

### MVP

- [ ] Preprocess: handle errors
- [ ] Preprocess: handle all TODO items
- [ ] Fastpack: cache file name account for absolute path to the entry point and
      all preprocessors
- [ ] RegularPacker: handle json require
- [ ] Documentation / Domain (1)

- [ ] Configuration options in package.json (2?)
- [ ] Use combinators for error output for nicer formatting? (2)
- [ ] Fastpack: handle static files (2)
- [ ] Fastpack: export URLs for static files (2)
- [ ] Support external command execution for LESS/SASS/other processing
- [ ] CSS support in import statements (webpack ICSS)? (2)
- [ ] FastpackTranspiler: PrivateName, PrivateField
- [ ] FastpackTranspiler: SpreadChild (2, in case we support something
  else than React)

- [x] Report execution time, number of modules & cache usage
- [x] `--postprocess` option
- [x] UI/UX (error reporting, config) [zindel] (1)
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
- [x] FlatPacker : `--target [ app | esm | cjs ]` for the last export statement
- [x] FlatPacker / RegularPacker: process.env.NODE_ENV is replaced with constant
- [x] FlatPacker / RegularPacker: set boolean `__DEV__` global based on mode
- [x] RegularPacker: add better API for cache (will enable watch mode later on)
- [x] FastpackTranspiler: spread operator in try/catch clause
- [x] FastpackTranspiler: add runtime
- [x] FlatPacker / RegularPacker: builtin modules (just empty files are used atm)?

### Heap

- [ ] Source maps (2)
- [ ] Think of integration with Flow
- [ ] Implement rest operator for try/catch statements when flow parser suppots it
