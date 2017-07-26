FPACK_TEST_PATH = "$(shell pwd)/test"


b: build
build: build-bin

train: build
	@_build/default/bin/fpack_test.exe --train $(FPACK_TEST_PATH)

test: build
	@_build/default/bin/fpack_test.exe $(FPACK_TEST_PATH)

top: build-top
	@rlwrap ./_build/default/top/main.exe

build-bin:
	@jbuilder build --dev bin/fpack.exe
	@jbuilder build --dev bin/fpack_test.exe

build-top:
	@jbuilder build top/main.exe

build-FastpackResolver:
	@jbuilder build --dev FastpackResolver/FastpackResolver.cma FastpackResolver/FastpackResolver.cmxa

build-FastpackSourceMap:
	@jbuilder build --dev FastpackSourceMap/FastpackSourceMap.cma FastpackSourceMap/FastpackSourceMap.cmxa

build-Fastpack:
	@jbuilder build --dev Fastpack/Fastpack.cma Fastpack/Fastpack.cmxa

bootstrap: install conf-merlin build

install:
	@opam install -y ocp-indent flow_parser fileutils cmdliner
	@opam pin add --dev-repo lwt
	@opam pin add merlin 'https://github.com/ocaml/merlin.git#beta'

conf-merlin:
	@jbuilder build bin/.merlin FastpackResolver/.merlin Fastpack/.merlin

clean:
	@rm -rf _build/
