FPACK_TEST_PATH = "$(shell pwd)/test"

b: build
build: build-bin

install:
	@esy install

train: build
	@esy _build/default/bin/fpack_test.exe --train $(FPACK_TEST_PATH)

test: build
	@esy _build/default/bin/fpack_test.exe $(FPACK_TEST_PATH)

top: build-top
	@esy rlwrap ./_build/default/top/main.exe

build-bin:
	@esy jbuilder build --dev bin/fpack.exe
	@esy jbuilder build --dev bin/fpack_test.exe

build-top:
	@esy jbuilder build top/main.exe

build-FastpackResolver:
	@esy jbuilder build --dev FastpackResolver/FastpackResolver.cma FastpackResolver/FastpackResolver.cmxa

build-FastpackSourceMap:
	@esy jbuilder build --dev FastpackSourceMap/FastpackSourceMap.cma FastpackSourceMap/FastpackSourceMap.cmxa

build-Fastpack:
	@esy jbuilder build --dev Fastpack/Fastpack.cma Fastpack/Fastpack.cmxa

build-dependencies:
	@esy build

bootstrap: install build-dependencies build conf-merlin

conf-merlin:
	@esy jbuilder build bin/.merlin FastpackResolver/.merlin Fastpack/.merlin

clean:
	@rm -rf _build/ _esybuild/ _esyinstall/ node_modules/
