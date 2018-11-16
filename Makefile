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
	@node scripts/test $(pattern)

train-integration: build-dev
	@node scripts/test --train $(pattern)

test-server:
	cd test && node server.js

bootstrap: install build setup-test

clean: clean-test
	@rm -rf _build/ node_modules/

bump-version:
	@node scripts/bump_version.js
