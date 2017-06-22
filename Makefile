b: build
build: build-bin

top: build-top
	@rlwrap ./_build/default/top/main.exe

build-bin:
	@jbuilder build --dev bin/fpack.exe

build-top:
	@jbuilder build top/main.exe

build-FastpackResolver:
	@jbuilder build FastpackResolver/FastpackResolver.cma FastpackResolver/FastpackResolver.cmxa

build-Fastpack:
	@jbuilder build Fastpack/Fastpack.cma Fastpack/Fastpack.cmxa

bootstrap: install conf-merlin build

install:
	@opam install -y ocp-indent flow_parser=0.40.0 fileutils cmdliner
	@opam pin add --dev-repo lwt
	@opam pin add merlin 'https://github.com/ocaml/merlin.git#beta'

conf-merlin:
	@jbuilder build bin/.merlin FastpackResolver/.merlin Fastpack/.merlin

clean:
	@rm -rf _build/
