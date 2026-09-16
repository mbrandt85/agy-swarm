.PHONY: all test lint clean

all: test lint

test:
	@bash tests/test_runners.sh

lint:
	@for f in scripts/*.sh bootstrap.sh tests/*.sh; do [ -f "$$f" ] || continue; bash -n "$$f" || exit 1; done

clean:
	@echo "🧹 Cleaning up teamwork agent logs..."
	@bash scripts/clean-teamwork-logs.sh >/dev/null 2>&1 || rm -rf .agents/teamwork_preview_* .agents/sentinel .agents/ORIGINAL_REQUEST.md
	@echo "✅ Cleanup complete!"
