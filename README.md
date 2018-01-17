# fastpack

[![Build Status](https://travis-ci.org/fastpack/fastpack.svg?branch=master)](https://travis-ci.org/fastpack/fastpack)

Pack JS code into a single bundle fast & easy.

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
