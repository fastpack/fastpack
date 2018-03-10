# fastpack

[![Build Status](https://travis-ci.org/fastpack/fastpack.svg?branch=master)](https://travis-ci.org/fastpack/fastpack)

Pack JS code into a single bundle fast & easy.

## Motivation

The goal for fastpack is to provide fast and robust development time bundling
for JavaScript applications which scales up to tens of thounsands of modules
without sacrificing development experience.

We want sub-1000ms bundle time and sub-100ms incremental rebundle time for
medium-sized applications (around 1000 modules). We are almost there.

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

To produce a production bundle:

```
% fpack ./index.js \
  --postprocess 'babel --presets env' \
  --postprocess 'uglify -cm'
```

Note that `babel`, `babel-preset-env` and `uglify-js` packages must be
installed.

## Reference

Run `fpack --help` to see the available invocation options:

```
NAME
       fpack - Pack JavaScript code into a single bundle

SYNOPSIS
       fpack [OPTION]... [INPUT]

ARGUMENTS
       INPUT
           Entry point JavaScript file

OPTIONS
       -d, --debug
           Print debug output

       --development
           Build bundle for development

       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of `auto',
           `pager', `groff' or `plain'. With `auto', the format is `pager` or
           `plain' whenever the TERM env var is `dumb' or undefined.

       --no-cache
           Do not use cache at all

       -o DIR, --output=DIR
           Output Directory. The target bundle will be DIR/index.js

       --postprocess=COMMAND
           Apply shell command on a bundle file. The content of the bundle
           will be sent to STDIN and STDOUT output will be collected. If
           multiple commands are specified they will be applied in the order
           of appearance

       --target=[ app | esm | cjs ]
           Deployment target.

       --transpile=PATTERN
           Apply transpilers to files matching PATTERN the regular expression.
           Currently available transpilers are: stripping Flow types, object
           spread & rest opertions, class properties (including statics),
           class/method decorators, and React-assumed JSX conversion.

       --version
           Show version information.

```

## Development

Make sure you have `esy` installed:

```bash
npm install -g esy
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

Currently release process is assumed to be performed on macOS with Docker
installed. Docker is needed to produce Linux x64 binaries.

Run:

```
% make dist-build
```

After that succeeds follow the printed instructions.
