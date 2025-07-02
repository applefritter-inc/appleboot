SHELL := /bin/bash
BUILDER := main.sh

.PHONY: require-root all run clean help

require-root:
	@ [ "$$(id -u)" -eq 0 ] || { \
	    echo "error: this rule must be run as root!!"; \
	    $(MAKE) help; \
	    exit 1; \
	}

all: run

run: require-root $(BUILDER)
	@ [ -n "$(BOARD)" ] || { \
	    echo "error: BOARD parameter is required."; \
	    $(MAKE) help; \
	    exit 1; \
	}
	@ echo "running builder with board $(BOARD)…"
	@ bash $(BUILDER) "$(BOARD)"

clean: require-root
	@ echo "cleaning directory!! this will clean all build files and artifacts."
	@ git clean -df

help:
	@ printf "\nUsage:\n"
	@ printf "  sudo make run BOARD=<board>   - Build & run for a given board\n"
	@ printf "  sudo make clean               - Remove all build artifacts\n"
	@ printf "  make help                     - Show this help message\n\n"
