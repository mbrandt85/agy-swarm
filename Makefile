.PHONY: all test lint

all: test lint

test:
	@bash tests/test_runners.sh

lint:
	@for f in scripts/*.sh bootstrap.sh tests/*.sh; do [ -f "$$f" ] || continue; bash -n "$$f" || exit 1; done
