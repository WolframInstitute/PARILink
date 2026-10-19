WOLFRAMSCRIPT ?= wolframscript
PARILINK_GP ?= gp
UPSTREAM_OUTPUT ?= build/upstream

.DEFAULT_GOAL := help
.PHONY: help all check test test-pari test-upstream deps docs build publish hooks

help:
	@printf '  make %-12s %s\n' \
		all 'source checks and tests without GP' \
		test-pari 'integration tests with an installed GP' \
		test-upstream 'compare a local PARI_SOURCE release with GP (see docs/compatibility.md)' \
		hooks 'enable the repository Git hooks' \
		deps 'fetch pinned documentation tools' \
		docs 'build documentation using PacletPage' \
		build 'build and check the paclet locally using PacletPage' \
		publish 'publish using PARILINK_PUBLISH_ACCOUNT'

all check test test-pari docs build publish:
	$(WOLFRAMSCRIPT) -file scripts/project.wls $@

test-upstream:
	python3 tests/upstream/prepare.py "$(PARI_SOURCE)" "$(PARILINK_GP)" \
		$(if $(PARI_DATA),--data "$(PARI_DATA)") --output "$(UPSTREAM_OUTPUT)" \
		$(if $(UPSTREAM_FILES),--files "$(UPSTREAM_FILES)")
	$(WOLFRAMSCRIPT) -file tests/upstream/replay.wls "$(UPSTREAM_OUTPUT)/manifest.json"

deps:
	bash scripts/fetch-deps.sh

hooks:
	git config core.hooksPath .githooks
