build: build-bin

build-bin:
	@jbuilder build bin/fpack.exe

build-FastpackResolver:
	@jbuilder build FastpackResolver/FastpackResolver.cma FastpackResolver/FastpackResolver.cmxa

build-Fastpack:
	@jbuilder build Fastpack/Fastpack.cma Fastpack/Fastpack.cmxa

bootstrap: install conf-merlin build

install:
	@opam install -y ocp-indent flow_parser=0.40.0 fileutils
	@opam pin add --dev-repo lwt
	@opam pin add merlin 'https://github.com/ocaml/merlin.git#beta'

conf-merlin:
	@jbuilder build bin/.merlin FastpackResolver/.merlin Fastpack/.merlin

clean:
	@rm -rf _build/
