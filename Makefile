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
	@opam install -y          \
		containers=1.3         \
		ocp-indent=1.6.1        \
		flow_parser=0.47.0      \
		fileutils=0.5.2         \
		cmdliner=1.0.0          \
		jbuilder=1.0+beta12     \
		merlin=3.0.2 lwt=3.1.0

conf-merlin:
	@jbuilder build bin/.merlin FastpackResolver/.merlin Fastpack/.merlin

clean:
	@rm -rf _build/
