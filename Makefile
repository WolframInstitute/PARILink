WOLFRAMSCRIPT ?= wolframscript
PARILINK_GP ?= gp
UPSTREAM_OUTPUT ?= build/upstream

.DEFAULT_GOAL := help
.PHONY: help all check test test-hooks test-pari test-upstream ci ci-build deps docs build runtime stage-runtime check-release publish hooks

help:
	@printf '  make %-12s %s\n' \
		all 'source checks and tests without GP' \
		test-hooks 'check the commit-message policy' \
		test-pari 'integration tests with bundled or installed GP' \
		runtime 'build GP and GMP for this platform' \
		stage-runtime 'include this platform runtime and PARI data in the paclet' \
		test-upstream 'compare a local PARI_SOURCE release with GP (see docs/compatibility.md)' \
		ci 'source checks and all tests in one Wolfram kernel' \
		ci-build 'CI checks, tests, and PacletPage build in one Wolfram kernel' \
		hooks 'enable the repository Git hooks' \
		deps 'fetch pinned documentation tools' \
		docs 'build documentation using PacletPage' \
		build 'build and check the paclet locally using PacletPage' \
		check-release 'verify a release-tag checkout in GitHub Actions' \
		publish 'publish the verified archive from a release-tag workflow'

all ci ci-build: hooks test-hooks
ci-build: deps

all check test test-pari ci ci-build docs build check-release publish:
	$(WOLFRAMSCRIPT) -file scripts/project.wls $@

test-hooks:
	python3 -m unittest discover -s tests -p 'test_*.py'

test-upstream:
	python3 tests/upstream/prepare.py "$(PARI_SOURCE)" "$(PARILINK_GP)" \
		$(if $(PARI_DATA),--data "$(PARI_DATA)") --output "$(UPSTREAM_OUTPUT)" \
		$(if $(UPSTREAM_FILES),--files "$(UPSTREAM_FILES)")
	$(WOLFRAMSCRIPT) -file tests/upstream/replay.wls "$(UPSTREAM_OUTPUT)/manifest.json"

deps:
	bash scripts/fetch-deps.sh

runtime:
	bash scripts/build-runtime.sh

stage-runtime:
	python3 scripts/runtime.py stage

hooks:
	git config core.hooksPath .githooks
