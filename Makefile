FPACK_TEST_PATH = "$(shell pwd)/test"

b: build

build:
	@esy build

build-dev:
	@esy b jbuilder build --dev bin/fpack.exe bin/fpack_test.exe bin/fpack_print.exe test/test_runner.exe

install:
	@esy install

train: build-dev
	@#@esy x fpack_test --train $(FPACK_TEST_PATH)
	@_build/default/bin/fpack_test.exe --train $(FPACK_TEST_PATH)

test: build-dev
	@#@esy x fpack_test $(FPACK_TEST_PATH)
	@_build/default/bin/fpack_test.exe $(FPACK_TEST_PATH)

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

#
# RELEASE
#

dist-build:
	@echo "[INFO] [RELEASE]: Building macOS binary release..."
	@$(MAKE) build
	@echo "[INFO] [RELEASE]: Building Linux x64 binary release..."
	@$(MAKE) -C linux-build build
	@echo "[INFO] [RELEASE]: Composing release package..."
	@cp linux-build/fpack.exe dist/vendor-linux/fpack.exe
	@cp _build/default/bin/fpack.exe dist/vendor-darwin/fpack.exe
	@echo "[INFO] [RELEASE]: DONE, now you can do the following:"
	@echo "[INFO]"
	@echo "[INFO]            1. cd dist"
	@echo "[INFO]            2. npm version patch|minor|major"
	@echo "[INFO]            3. npm publish"

dist-clean:
	@rm -rf dist/vendor-darwin/fpack.exe
	@rm -rf dist/vendor-linux/fpack.exe
