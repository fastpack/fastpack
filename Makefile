FPACK_TEST_PATH = "$(shell pwd)/test"

b: build

build:
	@esy build

build-dev:
	@esy b jbuilder build --dev bin/fpack.exe bin/fpack_test.exe bin/fpack_print.exe

install:
	@esy install

train: build
	@esy x fpack_test --train $(FPACK_TEST_PATH)

test: build
	@esy x fpack_test $(FPACK_TEST_PATH)

bootstrap: install build

clean:
	@rm -rf _build/ node_modules/
