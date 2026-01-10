.PHONY: coverage clean format verify

coverage:
	bash scripts/coverage.sh

clean:
	bash scripts/clean.sh

format:
	bash scripts/format.sh

verify:
	bash scripts/verify.sh
