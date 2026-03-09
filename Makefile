# =============================================================================
# Makefile for kickstart build system
# =============================================================================
MAKEFLAGS	+= --no-builtin-rules
MAKEFLAGS	+= --warn-undefined-variables
SHELL		:= /usr/bin/bash
.SHELLFLAGS	:= -euo pipefail -c

.DELETE_ON_ERROR:

# -----------------------------------------------------------------------------
# User-configurable variables
# -----------------------------------------------------------------------------
# Set to 1 to validate the final generated Kickstart files.
VALIDATE        ?= 1

# -----------------------------------------------------------------------------
# Source directories
# -----------------------------------------------------------------------------
HOSTSDIR        := $(CURDIR)/hosts
PROFILESDIR     := $(CURDIR)/profiles
SNIPPETSDIR     := $(CURDIR)/snippets

# -----------------------------------------------------------------------------
# Build directories
# -----------------------------------------------------------------------------
BUILDDIR        := $(CURDIR)/build
DISTDIR         := $(CURDIR)/dist

# -----------------------------------------------------------------------------
# Host inventory
# -----------------------------------------------------------------------------
HOSTS           := $(basename $(notdir $(wildcard $(HOSTSDIR)/*.ks)))

# -----------------------------------------------------------------------------
# Generic directory rule
# -----------------------------------------------------------------------------
# Directory targets use a trailing slash and are attached as order-only
# prerequisites so directory timestamp changes do not trigger rebuilds.
%/:
	@mkdir -p "$@"

# -----------------------------------------------------------------------------
# Main targets
# -----------------------------------------------------------------------------
.PHONY: all
# build all kickstart files
all: $(HOSTS:%=$(DISTDIR)/%.ks)

.PHONY: $(HOSTS)
# build kickstart file for host
$(HOSTS): %: $(DISTDIR)/%.ks

# -----------------------------------------------------------------------------
# Host-specific dependency fragments
# -----------------------------------------------------------------------------
# ksdeps.py derives:
# - source entry: hosts/<host>.ks
# - build root:   build/<host>
# - depfile:      build/<host>/deps.mk
# - final target: dist/<host>.ks
$(BUILDDIR)/%/deps.mk: $(HOSTSDIR)/%.ks $(CURDIR)/bin/ksdeps.py | $(BUILDDIR)/%/
	@echo "build/$*/deps.mk: building dependencies"
	@python3 bin/ksdeps.py "$*"

# Select only requested hosts when including dependency fragments.
GOALS           := $(filter $(HOSTS) all,$(MAKECMDGOALS))
HOSTS_SEL       := $(if $(filter all,$(GOALS)),$(HOSTS),$(filter $(HOSTS),$(GOALS)))

# Include host-specific dependency fragments unless cleanup was requested.
ifeq ($(filter clean distclean,$(MAKECMDGOALS)),)
-include $(HOSTS_SEL:%=$(BUILDDIR)/%/deps.mk)
endif

# -----------------------------------------------------------------------------
# Host-specific staging rules
# -----------------------------------------------------------------------------
# ksstage.sh is expected to:
# - copy files unchanged when no hosts/<host>.env exists
# - otherwise source hosts/<host>.env and render only allowed variables
# - write the destination atomically
#
# Staging layout per host:
# - build/<host>/host.ks
# - build/<host>/profiles/<name>.ks
# - build/<host>/snippets/<name>.ks

define HOST_STAGE_RULES
$(BUILDDIR)/$(1)/host.ks: $(HOSTSDIR)/$(1).ks $(wildcard $(HOSTSDIR)/$(1).env) $(CURDIR)/bin/ksstage.sh | $(BUILDDIR)/$(1)/
	@echo "build/$(1)/host.ks: staging host entry"
	@bin/ksstage.sh "$(1)" "$$<" "$$@"

$(BUILDDIR)/$(1)/profiles/%.ks: $(PROFILESDIR)/%.ks $(wildcard $(HOSTSDIR)/$(1).env) $(CURDIR)/bin/ksstage.sh | $(BUILDDIR)/$(1)/profiles/
	@echo "build/$(1)/profiles/$$*.ks: staging profile"
	@bin/ksstage.sh "$(1)" "$$<" "$$@"

$(BUILDDIR)/$(1)/snippets/%.ks: $(SNIPPETSDIR)/%.ks $(wildcard $(HOSTSDIR)/$(1).env) $(CURDIR)/bin/ksstage.sh | $(BUILDDIR)/$(1)/snippets/
	@echo "build/$(1)/snippets/$$*.ks: staging snippet"
	@bin/ksstage.sh "$(1)" "$$<" "$$@"
endef

$(foreach host,$(HOSTS),$(eval $(call HOST_STAGE_RULES,$(host))))

# -----------------------------------------------------------------------------
# Final Kickstart build
# -----------------------------------------------------------------------------
# ksflatten.sh derives:
# - staged entry: build/<host>/host.ks
# - final file:   dist/<host>.ks
#
# The tool is expected to perform atomic writes itself. Validation is controlled
# via KS_VALIDATE.
$(DISTDIR)/%.ks: $(BUILDDIR)/%/deps.mk $(CURDIR)/bin/ksflatten.sh | $(DISTDIR)/
	@echo "dist/$*.ks: building flattened kickstart"
	@bin/ksflatten.sh "$*" $(if $(filter 1,$(VALIDATE)),--validate,)
	@echo "dist/$*.ks: build completed."

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
.PHONY: clean
# remove build artifacts, keep build/ and deps if you add any later
clean:
	@echo "clean: removing dist artifacts"
	@rm -rf "$(DISTDIR)"

.PHONY: distclean
# remove all build artifacts, including build/ and deps
distclean mrproper: clean
	@echo "distclean: removing build artifacts"
	@rm -rf "$(BUILDDIR)"

# -----------------------------------------------------------------------------
# Local test targets
# -----------------------------------------------------------------------------

TEST_HOSTS := $(basename $(notdir $(wildcard $(HOSTSDIR)/example*.ks)))

.PHONY: test $(TEST_HOSTS:%=test-%)
test: $(TEST_HOSTS:%=test-%)

$(TEST_HOSTS:%=test-%): test-%: $(DISTDIR)/%.ks bin/test.sh
	@bash bin/test.sh "$*"
