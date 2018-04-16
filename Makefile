.PHONY: test

b: build

build:
	@esy build

build-dev:
	@esy b jbuilder build --dev bin/fpack.exe

install:
	@esy install

test:
	@esy jbuilder runtest --dev

setup-test:
	cd test && for TEST in `ls`; \
	   do [ -d "$$TEST" ] \
	      && [ -f "$$TEST/package.json" ] \
		  && echo "Test: $$TEST" \
		  && cd "$$TEST" \
		  && yarn \
		  && cd ..; \
		done \
	|| echo "Setup tests: done"

clean-test:
	cd test && for TEST in `ls`; \
	   do [ -d "$$TEST" ] \
	      && [ -d "$$TEST/node_modules" ] \
		  && rm -rf "$$TEST/node_modules"; \
		done \
	|| echo "Cleanup tests: done"

test-integration: build-dev
	@test/test.sh $(pattern)

train-integration: build-dev
	@test/update.sh $(pattern)

test-server:
	cd test && node server.js

fetch:
	git submodule init
	git submodule update

bootstrap: fetch install build setup-test

clean: clean-test
	@rm -rf _build/ node_modules/

#
# RELEASE
#

release-patch release-minor release-major:
	@echo "[INFO]  [RELEASE] Checking if working tree is clean..."
	@git diff-index --quiet HEAD --ignore-submodules -- \
		|| (echo "[ERROR] [RELEASE] Working tree is dirty..." && exit 1)
	@npm version --force $(@:release-%=%)
	@echo "[INFO]  [RELEASE] Setting version and git commit info..."
	@sed \
		-i '' \
		-e "s/%%VERSION%%/$$(node -p "require('./package.json').version")/g" \
		Fastpack/Version.ml
	@sed \
		-i '' \
		-e "s/%%COMMIT%%/$$(git log --pretty=format:'%h' -n 1)/g" \
		Fastpack/Version.ml
	@$(MAKE) release-dist
	@git checkout -- Fastpack/Version.ml

release-dist:
	@echo "[INFO]  [RELEASE] Building macOS binary release..."
	@$(MAKE) build
	@echo "[INFO]  [RELEASE] Building Linux x64 binary release..."
	@$(MAKE) -C linux-build build
	@echo "[INFO]  [RELEASE] Composing release package..."
	@cp linux-build/fpack.exe dist/vendor-linux/fpack.exe
	@cp _build/default/bin/fpack.exe dist/vendor-darwin/fpack.exe
	@echo "[INFO]  [RELEASE] DONE, now you can do the following:"
	@echo "[INFO]"
	@echo "[INFO]            - Go to the release directory: cd dist"
	@echo "[INFO]            - Check that everything is ok: npm i -g ."
	@echo "[INFO]            - Publish to npm registry: npm publish"
	@echo "[INFO]            - Go back: cd ../"
	@echo "[INFO]            - Push release tag to GitHub: git push"

release-clean:
	@rm -rf dist/vendor-darwin/fpack.exe
	@rm -rf dist/vendor-linux/fpack.exe
