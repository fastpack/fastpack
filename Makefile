.PHONY: test bump-version

b: build

# this generates the flags needed for building the static binary on linux
bin/link_flags:
	@esy node scripts/gen_link_flags.js

FastpackUtil/c_link_flags:
	@esy node scripts/gen_c_link_flags.js

build: bin/link_flags FastpackUtil/c_link_flags
	@esy build

build-dev: bin/link_flags FastpackUtil/c_link_flags
	@esy b refmterr jbuilder build --dev bin/fpack.exe

install:
	@esy install

test: build-dev
	@esy jbuilder runtest --dev --diff-command "git --no-pager diff --no-index --color"

train: build-dev
	@esy jbuilder runtest --auto-promote --dev --diff-command "git --no-pager diff --no-index --color"

setup-test:
	@esy node scripts/setupTest.js

clean-test:
	@esy node scripts/cleanTest.js

test-integration: build-dev
	@node -r ./_esy/default/pnp.js scripts/test $(pattern)

train-integration: build-dev
	@node -r ./_esy/default/pnp.js scripts/test --train $(pattern)

test-server:
	cd test && node server.js

bootstrap: install build setup-test

clean: clean-test
	@rm -rf _build/ node_modules/

bump-version:
	@esy node scripts/bump_version.js
