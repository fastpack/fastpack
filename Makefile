.PHONY: test bump-version

b: build

build:
	@esy build

build-dev:
	@esy b refmterr jbuilder build --dev bin/fpack.exe

install:
	@esy install

test: build-dev
	@esy jbuilder runtest --dev --diff-command "git --no-pager diff --no-index --color"

train: build-dev
	@esy jbuilder runtest --auto-promote --dev --diff-command "git --no-pager diff --no-index --color"

setup-test:
	@esy x node scripts/setupTest.js

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
