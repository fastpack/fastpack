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

setup-jest:
	cd test && yarn \
	&& for TEST in `ls`; \
	   do [ -d "$$TEST" ] \
	      && [ -f "$$TEST/package.json" ] \
		  && echo "Test: $$TEST" \
		  && cd "$$TEST" \
		  && yarn \
		  && cd ..; \
		done \
	|| echo "Setup tests: done"

clean-jest:
	cd test && rm -rf node_modules \
	&& for TEST in `ls`; \
	   do [ -d "$$TEST" ] \
	      && [ -d "$$TEST/node_modules" ] \
		  && rm -rf "$$TEST/node_modules"; \
		done \
	|| echo "Cleanup tests: done"

test-jest: build-dev
	cd test && yarn jest

train-jest: build-dev
	cd test && yarn jest --updateSnapshot

fetch:
	git submodule init
	git submodule update

bootstrap: fetch install build setup-jest

clean: clean-jest
	@rm -rf _build/ node_modules/

