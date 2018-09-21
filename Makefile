.PHONY: test bump-version

b: build

# this generates the flags needed for building the static binary on linux
bin/link_flags:
	@node scripts/gen_link_flags.js > bin/link_flags

build: bin/link_flags
	@esy build

build-dev: bin/link_flags
	@esy b refmterr jbuilder build --dev bin/fpack.exe

install:
	@esy install

test: build-dev
	@esy jbuilder runtest --dev --diff-command "git --no-pager diff --no-index --color"

train: build-dev
	@esy jbuilder runtest --auto-promote --dev --diff-command "git --no-pager diff --no-index --color"

setup-test:
	cd test && for TEST in `ls`; \
	   do [ -d "$$TEST" ] \
	      && [ -f "$$TEST/package.json" ] \
		  && echo "Test: $$TEST" \
		  && cd "$$TEST" \
		  && yarn \
		  && cd ..; \
		done \
	|| echo "Setup tests: done"

clean-test:
	cd test && for TEST in `ls`; \
	   do [ -d "$$TEST" ] \
		  && [ -f "$$TEST/package.json" ] \
	      && [ -d "$$TEST/node_modules" ] \
		  && rm -rf "$$TEST/node_modules"; \
		done \
	|| echo "Cleanup tests: done"

test-integration: build-dev
	@test/test.sh $(pattern)

train-integration: build-dev
	@test/update.sh $(pattern)

test-server:
	cd test && node server.js

fetch:
	git submodule init
	git submodule update

bootstrap: fetch install build setup-test

clean: clean-test
	@rm -rf _build/ node_modules/

bump-version:
	@node scripts/bump_version.js
