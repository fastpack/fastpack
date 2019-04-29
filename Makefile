.PHONY: test bump-version build build-dev

b: build

build:
	@esy build

build-dev:
	@esy b refmterr dune build bin/fpack.exe

install:
	@esy install

test: build-dev
	@esy dune runtest --diff-command "git --no-pager diff --no-index --color"

train: build-dev
	@esy dune runtest --auto-promote --diff-command "git --no-pager diff --no-index --color"

setup-test:
	node scripts/setupTest.js

clean-test:
	@esy x node scripts/cleanTest.js

test-integration: build-dev
	@node -r ./_esy/default/pnp.js scripts/test $(pattern)

train-integration: build-dev
	@node -r ./_esy/default/pnp.js scripts/test --train $(pattern)

test-server:
	cd test && esy x node server.js

bootstrap: install build setup-test

clean: clean-test
	@rm -rf _build/ node_modules/

bump-version:
	@esy x node scripts/bump_version.js
