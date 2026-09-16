.PHONY: all test lint clean

all: test lint

test:
	@bash tests/test_runners.sh

lint:
	@for f in scripts/*.sh bootstrap.sh tests/*.sh; do [ -f "$$f" ] || continue; bash -n "$$f" || exit 1; done

clean:
	@echo "🧹 Cleaning up teamwork agent logs..."
	@bash scripts/clean-teamwork-logs.sh >/dev/null 2>&1 || (chmod -R u+w .agents/teamwork_preview_* .agents/sentinel 2>/dev/null || true; rm -rf .agents/teamwork_preview_* .agents/sentinel .agents/ORIGINAL_REQUEST.md)
	@echo "✅ Cleanup complete!"
