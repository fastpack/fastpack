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

setup-jest:
	cd test && yarn

clean-jest:
	cd test && rm -rf node_modules

test-jest: build-dev
	cd test && yarn jest

train-jest: build-dev
	cd test && yarn jest --updateSnapshot

fetch:
	git submodule init
	git submodule update

# EXAMPLES

## Simple CRA-based application

build-react-app-simple:
	@cd examples/react-app-simple && yarn install

test-react-app-simple: build-dev
	@scripts/test-example.sh \
		react-app-simple \
		src/index.js \
		--transpile '^src'


## Tranpiling Test

test-transpile: build-dev
	@scripts/test-example.sh \
		transpile \
		src/index.js \
		-d --transpile '^src'


build-examples: build-react-app-simple
	@echo "Examples built."

clean-examples:
	@rm -rf examples/react-app-simple/node_modules


bootstrap: fetch install build build-examples setup-jest

clean: clean-examples clean-jest
	@rm -rf _build/ node_modules/

