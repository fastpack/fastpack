build: build-bin build-FastpackResolver

build-bin:
	@jbuilder build bin/fastpack.exe

build-FastpackResolver:
	@jbuilder build bin/fastpack.exe

bootstrap: install conf-merlin build

install:
	@opam install -y ocp-indent flow_parser=0.40.0 fileutils
	@opam pin add --dev-repo lwt
	@opam pin add merlin 'https://github.com/ocaml/merlin.git#beta'

conf-merlin:
	@jbuilder build bin/.merlin FastpackResolver/.merlin

clean:
	@rm -rf _build/
