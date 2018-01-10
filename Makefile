FPACK_TEST_PATH = "$(shell pwd)/test"

b: build

build:
	@esy build

build-dev:
	@esy b jbuilder build --dev bin/fpack.exe bin/fpack_test.exe bin/fpack_print.exe

install:
	@esy install

train: build-dev
	@#@esy x fpack_test --train $(FPACK_TEST_PATH)
	@_build/default/bin/fpack_test.exe --train $(FPACK_TEST_PATH)

test: build-dev
	@#@esy x fpack_test $(FPACK_TEST_PATH)
	@_build/default/bin/fpack_test.exe $(FPACK_TEST_PATH)

fetch:
	git submodule init
	git submodule update

build-react-app-simple:
	@cd examples/react-app-simple && yarn install

test-react-app-simple: build-dev
	@cd examples/react-app-simple \
		&& yarn run fpack:build:regular:prod \
		&& yarn run fpack:build:regular:dev

build-examples: build-react-app-simple
	@echo "Examples built."

clean-examples:
	@rm -rf examples/react-app-simple/node_modules

bootstrap: fetch install build build-examples

clean: clean-examples
	@rm -rf _build/ node_modules/
