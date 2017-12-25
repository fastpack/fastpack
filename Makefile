FPACK_TEST_PATH = "$(shell pwd)/test"

b: build

build:
	@esy build

build-dev:
	@esy b jbuilder build --dev bin/fpack.exe bin/fpack_test.exe bin/fpack_print.exe

install:
	@esy install

train: build-dev
	@esy x fpack_test --train $(FPACK_TEST_PATH)

test: build-dev
	@esy x fpack_test $(FPACK_TEST_PATH)

fetch:
	git submodule init
	git submodule update

bootstrap: fetch install build

clean:
	@rm -rf _build/ node_modules/
