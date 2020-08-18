# ----------------------------------------------------------------------------
# global

SHELL := /usr/bin/env bash

TAG = $(shell cat ./src/VERSION.txt)

CIRCLECI_FLAGS ?=
ifneq (${V},)
	CIRCLECI_FLAGS += --debug
endif

CAT_COMMAND ?= cat
ifneq ($(shell command -v pygmentize),)
	CAT_COMMAND=pygmentize -l yaml
endif
ifneq ($(shell command -v bat),)
	CAT_COMMAND=bat -l yaml -
endif

# ----------------------------------------------------------------------------
# target

## circleci command

.PHONY: circleci/pack
circleci/pack:
	@circleci config pack $(strip ${CIRCLECI_FLAGS}) src > src/${ORB}.yml

.PHONY: circleci/validate
circleci/validate:
	@circleci orb validate $(strip ${CIRCLECI_FLAGS}) ./src/${ORB}.yml

.PHONY: circleci/process
circleci/process:
	@circleci orb process $(strip ${CIRCLECI_FLAGS}) ./src/${ORB}.yml | ${CAT_COMMAND}

.PHONY: circleci/create
circleci/create: CIRCLECI_FLAGS+=--no-prompt
circleci/create:
	@circleci orb create $(strip ${CIRCLECI_FLAGS}) ${NAMESPACE}/${ORB} > /dev/null 2>&1 || true


## general

.PHONY: create
create:  ## Creates orb registry to org namespace.
create: circleci/create

.PHONY: pack
pack:  ## Packs the orb.
pack: clean circleci/pack

.PHONY: validate
validate:  ## Validates the orb.
validate: pack circleci/validate
	@${MAKE} --silent clean

.PHONY: process
process:  ## Processes the orb.
process: pack validate circleci/process
	@${MAKE} --silent clean

.PHONY: yamllint
yamllint:  ## Runs the yamllint linter.
yamllint: clean pack
	@yamllint -s .
	@${MAKE} --silent clean


## publish

.PHONY: publish/dev
publish/dev:  ## Publish to dev orb registry.
publish/dev: TAG=dev:$(shell printf 0.%.1f $$(echo $$(printf $$(cat src/VERSION.txt) | awk -F. '{OFS="."}{print $$2,$$3}')+0.1 | bc))
publish/dev: publish

.PHONY: publish
publish:  ## Publish to production orb registry.
publish: circleci/pack circleci/validate circleci/create
	circleci orb publish $(strip $(CIRCLECI_FLAGS)) ./src/${ORB}.yml ${NAMESPACE}/${ORB}@${TAG}
	@${MAKE} --silent clean


## clean

.PHONY: clean
clean:  ## Clean packed orb.
	@${RM} ./src/${ORB}.yml


## release

.PHONY: release
release:
	git add src/VERSION.txt
	git commit -m "VERSION: bump ${TAG} version"
	git push
	hub release create -m 'v${TAG}' v${TAG}
	git fetch --all --prune --verbose


## boilerplate

.PHONY: boilerplate/orb/%
boilerplate/orb/%:  ## Creates the orb file based on boilerplate.*.txt.
boilerplate/orb/%: BOILERPLATE_ORB_DIR=$(*D)
boilerplate/orb/%: BOILERPLATE_ORB_NAME=$(*F)
boilerplate/orb/%:
	@if [ ! -d "src/${BOILERPLATE_ORB_DIR}" ]; then mkdir -p "src/${BOILERPLATE_ORB_DIR}"; fi
	@cat ./hack/boilerplate/boilerplate.${BOILERPLATE_ORB_DIR}.txt > src/${BOILERPLATE_ORB_DIR}/${BOILERPLATE_ORB_NAME}


## help

.PHONY: help
help:  ## Show this help.
	@perl -nle 'BEGIN {printf "Usage:\n  make \033[33m<target>\033[0m\n\nTargets:\n"} printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 if /^([a-zA-Z\/_-].+)+:.*?\s+## (.*)/' ${MAKEFILE_LIST}
