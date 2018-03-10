.DELETE_ON_ERROR:

INPUT_DIR = /tmp/fastpack-linux-build-input
OUTPUT_DIR = /tmp/fastpack-linux-build-output

prepare:
	@echo "[INFO] linux-build: [host] packing sources tarball..."
	@rm -rf $(INPUT_DIR) $(OUTPUT_DIR)
	@mkdir $(INPUT_DIR) $(OUTPUT_DIR)
	@(cd ../ && \
		tar cf $(INPUT_DIR)/src.tar \
		--exclude .git \
		--exclude linux-build \
		--exclude _build \
		.)
	@cp Makefile $(INPUT_DIR)/Makefile

.dockerImageId:
	@echo "[INFO] linux-build: [host] preparing docker image..."
	@docker build -q . > $(@)

build: prepare .dockerImageId
	@echo "[INFO] linux-build: [host] running build in docker container..."
	@echo "[NOTE] linux-build: [host] ~/.esy-linux will be created and used as esy store for linux"
	@docker run \
		--volume $(HOME)/.esy-linux:/root/.esy \
		--volume $(INPUT_DIR):/src \
		--volume $(OUTPUT_DIR):/out \
		-it $(shell cat .dockerImageId) bash -c 'cd /src && make build-on-target'
	@echo "[INFO] linux-build: [host] DONE"
	@cp $(OUTPUT_DIR)/fpack.exe ./

clean:
	@rm -rf fpack.exe .dockerImageId

build-on-target:
	@echo "[INFO] linux-build: [target] unpacking sources tarball..."
	@tar -xf src.tar
	@echo "[INFO] linux-build: [target] starting build..."
	@esy build
	@cp _build/default/bin/fpack.exe /out/fpack.exe
