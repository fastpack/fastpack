build: build-bin

build-bin:
	@jbuilder build bin/fastpack.exe

bootsrap: install conf-merlin build

install:
	@opam install -y ocp-indent flow_parser
	@opam pin add --dev-repo lwt
	@opam pin add merlin 'https://github.com/ocaml/merlin.git#beta'

conf-merlin:
	@jbuilder build bin/.merlin

clean:
	@rm -rf _build/
