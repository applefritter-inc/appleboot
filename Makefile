ifneq ($(shell id -u),0)
$(error this makefile must be run as root!! try: sudo $(MAKE) $(MAKECMDGOALS))
endif

SHELL := /bin/bash
BUILDER := main.sh

.PHONY: all run clean
all: run

run: $(BUILDER)
ifeq ($(strip $(BOARD)),)
$(error BOARD is required. usage: sudo make run BOARD=<board>)
endif
	@echo "running builder with board ${BOARD}..."
	@bash $(BUILDER) "$(BOARD)"

clean:
	@echo "cleaning directory!! this will clean all build files and artifacts."
	@git clean -df