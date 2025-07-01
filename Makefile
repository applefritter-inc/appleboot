ifneq ($(shell id -u),0)
$(error this makefile must be run as root!! try: sudo make $(MAKECMDGOALS))
endif

SHELL := /bin/bash
BUILDER := main.sh

.PHONY: all run clean
all: run

run: ${BUILDER}
	@echo "running builder..."
	@bash ${BUILDER}

clean:
	@echo "cleaning directory!! this will clean all build files and artifacts."
	@git clean -df