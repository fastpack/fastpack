# fastpack

[![Build Status](https://dev.azure.com/fastpack/fastpack/_apis/build/status/fastpack.fastpack)](https://dev.azure.com/fastpack/fastpack/_build/latest?definitionId=1)

Pack JS code into a single bundle fast & easy.

## Motivation

The goal for fastpack is to provide fast and robust development time bundling
for JavaScript applications which scales up to tens of thousands of modules
without sacrificing development experience.

We want sub-1000ms bundle time and sub-100ms incremental rebundle time for
medium-sized applications (around 1000 modules). We are finally there!

## Installation

You can install via npm (or yarn):

```
% npm install fpack
```

## Usage

To produce a development bundle:

```
% fpack --development ./index.js
```

**Please note**, bundling in production mode is temporarily deisabled. Always
use the `--development` flag for now.

Note that `babel`, `babel-preset-env` and `uglify-js` packages must be
installed.

## Reference

Run `fpack --help` to see the available invocation options:

```
NAME
       fpack - Pack JavaScript code into a single bundle

SYNOPSIS
       fpack COMMAND ...

COMMANDS
       PLEASE NOTE: production mode is temporarily disabled. In the meantime,
       please always use the `--development` flag.

       build
           rebuild the bundle on a file change

       help
           Show this message and exit

       serve
           watch for file changes, rebuild bundle & serve

       watch
           watch for file changes and rebuild the bundle

ARGUMENTS
       ENTRY POINTS
           Entry points. Default: ['.']

OPTIONS
       -d, --debug
           Print debug output

       --development
           Build bundle for development

       --dry-run
           Run all the build operations without storing the bundle in the
           file system

       --mock=PACKAGE[:SUBSTITUTE]
           Mock PACKAGE requests with SUBSTITUTE requests. If SUBSTITUTE is
           omitted empty module is used.

       -n NAME, --name=NAME (absent=index.js)
           Output File Name. The target bundle filename will be NAME

       --no-cache
           Do not use cache at all (effective in development mode only)

       --node-modules=PATH, --nm=PATH
           Paths to 'node_modules' directory. Should be inside the project
           directory.. Defaults to ['node_modules']

       -o DIR, --output=DIR (absent=./bundle)
           Output Directory. The target bundle will be DIR/index.js.

       --postprocess=COMMAND
           Apply shell command on a bundle file. The content of the bundle
           will be sent to STDIN and STDOUT output will be collected. If
           multiple commands are specified they will be applied in the order
           of appearance

       --preprocess=PATTERN:PROCESSOR?OPTIONS[!...]
           Preprocess modules matching the PATTERN with the PROCESSOR.
           Optionally, the processor may receive some OPTIONS in form:
           'x=y&a=b'. There are 2 kinds of currently supported processors:
           'builtin' and the Webpack loader. 'builtin' preprocessor provides
           the following transpilers: stripping Flow types, object spread &
           rest operators, class properties (including statics), class/method
           decorators, and React-assumed JSX conversion. 'builtin' may be
           skipped when setting this option, i.e. '\.js$' and '\.js$:builtin'
           are absolutely equal. An example of using the Webpack loader:
           '\.js$:babel-loader?filename=.babelrc'.

       --project-root=PATH (absent=.)
           Ancestor to which node_modules will be resolved.. Defaults to '.'

       --report=[ json ] (absent=text)
           Output packer statistics

       --resolve-extension=EXTENSION
           Provide extensions to be considered by the resolver for the
           extension-less path. Extensions will be tried in the specified
           order. If no extension should be tried, provide '' as an argument.
           Defaults to [.js, .json]

       --target=[ app | esm | cjs ] (absent=app)
           Deployment target.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of `auto',
           `pager', `groff' or `plain'. With `auto', the format is `pager` or
           `plain' whenever the TERM env var is `dumb' or undefined.

       --version
           Show version information.
```

## Development

Make sure you have `esy` (at least `0.2.8` version) installed:

```bash
npm install -g esy@0.2.11
```

Now install dependencies & build everything:

```bash
make bootstrap
```

Then to produce the executable:

```bash
make build
```

To run tests:

```bash
make test
make test-integration
```

To test compiled executables prepend with `esy x`:

```bash
esy x fpack
```

As merlin and others live inside sandboxed environment you'd want to execute
your editor from inside it:

```bash
esy vim
esy nvim
esy vscode
esy sublime
```

Alternatively you can enter into sandboxed shell:

```bash
esy shell
```

And execute commands from there.

## Release Process

The NPM package is built on every commit to the `master` branch by the
Microsoft Azure Pipelines (see Artifacts/fpack). Publishing it on npmjs.org
remains manual for now.
