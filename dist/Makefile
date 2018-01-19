.PHONY: install

PLATFORM := unsupported

UNAME := $(shell uname -s)
ifeq ($(UNAME),Linux)
	PLATFORM := linux
endif
ifeq ($(UNAME),Darwin)
	PLATFORM := darwin
endif

install:
	cp -r vendor-$(PLATFORM)/fpack.exe ./fpack
