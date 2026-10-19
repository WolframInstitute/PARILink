WOLFRAMSCRIPT ?= wolframscript

.DEFAULT_GOAL := help
.PHONY: help all check test test-pari deps docs build publish

help:
	@printf '  make %-12s %s\n' \
		all 'source checks and tests without GP' \
		test-pari 'integration tests with an installed GP' \
		deps 'fetch pinned documentation tools' \
		docs 'build documentation using PacletPage' \
		build 'build and check the paclet locally using PacletPage' \
		publish 'publish using PARILINK_PUBLISH_ACCOUNT'

all check test test-pari docs build publish:
	$(WOLFRAMSCRIPT) -file scripts/project.wls $@

deps:
	bash scripts/fetch-deps.sh
