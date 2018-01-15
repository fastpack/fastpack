FPACK = ../../_build/default/bin/fpack.exe
BSB = ./node_modules/.bin/bsb

.PHONY: build
build:
	$(BSB) -make-world
	$(FPACK) ./src/index.bs.js --output ./build/index.js

.PHONY: clean
clean:
	rm -rf build lib
	find src -name '*.bs.js' -delete
