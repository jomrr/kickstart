# =============================================================================
# Makefile for Kickstart build system
# =============================================================================
MAKEFLAGS       += --no-builtin-rules
MAKEFLAGS       += --warn-undefined-variables
SHELL           := /usr/bin/bash
.SHELLFLAGS     := -euo pipefail -c

# -----------------------------------------------------------------------------
# User-configurable variables
# -----------------------------------------------------------------------------
# Set to 1 to validate flattened Kickstart files before publishing them.
VALIDATE        ?= 1

# -----------------------------------------------------------------------------
# Repository paths
# -----------------------------------------------------------------------------
BINDIR          := $(CURDIR)/bin
HOSTSDIR        := $(CURDIR)/hosts
PROFILESDIR     := $(CURDIR)/profiles
SNIPPETSDIR     := $(CURDIR)/snippets
BUILDDIR        := $(CURDIR)/build
DISTDIR         := $(CURDIR)/dist

# -----------------------------------------------------------------------------
# Helper tools
# -----------------------------------------------------------------------------
KSDEPS          := $(BINDIR)/ksdeps.py
KSSTAGE         := $(BINDIR)/ksstage.py

# -----------------------------------------------------------------------------
# Host inventory
# -----------------------------------------------------------------------------
HOSTS           := $(basename $(notdir $(wildcard $(HOSTSDIR)/*.ks)))
TEST_HOSTS      := $(basename $(notdir $(wildcard $(HOSTSDIR)/example*.ks)))

# -----------------------------------------------------------------------------
# Source inventory
# -----------------------------------------------------------------------------
# Existing per-host dependency fragments are included only when they already
# exist. They are never created during parse time.
HOST_ENVS       := $(wildcard $(HOSTSDIR)/*.env)

# -----------------------------------------------------------------------------
# Makefile settings
# -----------------------------------------------------------------------------
.DEFAULT_GOAL   := all
.DELETE_ON_ERROR:

# Keep generated directories and host version files.
.PRECIOUS: %/
.SECONDARY: $(HOSTS:%=$(BUILDDIR)/%/ks.version)

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
.PHONY: deps
# Generate all per-host dependency fragments explicitly.
deps: $(HOSTS:%=$(BUILDDIR)/%/deps.mk)

.PHONY: stage
# Stage all hosts explicitly.
stage: $(HOSTS:%=$(BUILDDIR)/%/staged/host.ks)

.PHONY: all
# Build all published Kickstart files.
all: $(HOSTS:%=$(DISTDIR)/%.ks)

.PHONY: flat
# Build all flattened Kickstart artifacts without publishing them.
flat: $(HOSTS:%=$(BUILDDIR)/%/flat.ks)

.PHONY: validate
# Validate all flattened Kickstart artifacts.
validate: $(HOSTS:%=$(BUILDDIR)/%/validate.log)

.PHONY: $(HOSTS)
# Build one published Kickstart file.
$(HOSTS): %: $(DISTDIR)/%.ks

.PHONY: $(HOSTS:%=flat-%)
# Build one flattened Kickstart artifact.
$(HOSTS:%=flat-%): flat-%: $(BUILDDIR)/%/flat.ks

.PHONY: $(HOSTS:%=validate-%)
# Validate one flattened Kickstart artifact.
$(HOSTS:%=validate-%): validate-%: $(BUILDDIR)/%/validate.log

# -----------------------------------------------------------------------------
# Generated dependency fragments
# -----------------------------------------------------------------------------
# Generate one depfile per host. The depfile contains only exact source
# dependencies, not build logic.
$(BUILDDIR)/%/deps.mk: $(HOSTSDIR)/%.ks $(KSDEPS) | $(BUILDDIR)/%/
	@echo "build/$*/deps.mk: building dependencies"
	@python3 $(KSDEPS) "$*"

# Include only existing per-host depfiles. Missing depfiles are never created
# during parse time.
-include $(wildcard $(BUILDDIR)/*/deps.mk)

# -----------------------------------------------------------------------------
# Host staging
# -----------------------------------------------------------------------------
# Stage one host into build/<host>/staged.
$(BUILDDIR)/%/staged/host.ks: $(BUILDDIR)/%/deps.mk $(KSSTAGE) | $(BUILDDIR)/%/
	@echo "build/$*/staged/host.ks: staging kickstart tree"
	@python3 $(KSSTAGE) "$*"

# -----------------------------------------------------------------------------
# Kickstart version artifact
# -----------------------------------------------------------------------------
# Extract the Kickstart syntax version from the staged host entry.
# Fall back to DEVEL when no explicit header is present.
$(BUILDDIR)/%/ks.version: $(BUILDDIR)/%/staged/host.ks | $(BUILDDIR)/%/
	@echo "build/$*/ks.version: extracting kickstart version"
	@version="$$(sed -nE 's/^[[:space:]]*#version[[:space:]]*=[[:space:]]*([^[:space:]]+)[[:space:]]*$$/\1/p' "$<" | head -n 1)"; \
	printf '%s\n' "$${version:-DEVEL}" > "$@"

# -----------------------------------------------------------------------------
# Flattened build artifact
# -----------------------------------------------------------------------------
$(BUILDDIR)/%/flat.ks: $(BUILDDIR)/%/staged/host.ks $(BUILDDIR)/%/ks.version | $(BUILDDIR)/%/
	@echo "build/$*/flat.ks: flattening kickstart"
	@ksflatten -v "$$(cat "$(BUILDDIR)/$*/ks.version")" -c "$(BUILDDIR)/$*/staged/host.ks" -o "$@"
	@echo "build/$*/flat.ks: build completed."

# -----------------------------------------------------------------------------
# Validation artifact
# -----------------------------------------------------------------------------
$(BUILDDIR)/%/validate.log: $(BUILDDIR)/%/flat.ks $(BUILDDIR)/%/ks.version | $(BUILDDIR)/%/
	@echo "build/$*/validate.log: validating kickstart"
	@ksvalidator -v "$$(cat "$(BUILDDIR)/$*/ks.version")" "$<" > "$@" 2>&1
	@echo "build/$*/validate.log: validation completed."

# -----------------------------------------------------------------------------
# Published Kickstart artifact
# -----------------------------------------------------------------------------
ifeq ($(filter 1,$(VALIDATE)),1)
$(DISTDIR)/%.ks: $(BUILDDIR)/%/validate.log | $(DISTDIR)/
else
$(DISTDIR)/%.ks: $(BUILDDIR)/%/flat.ks | $(DISTDIR)/
endif
	@echo "dist/$*.ks: publishing flattened kickstart"
	@cp -- "$(BUILDDIR)/$*/flat.ks" "$@"
	@echo "dist/$*.ks: build completed."

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
.PHONY: clean
# Remove published artifacts only.
clean:
	@echo "$@: removing dist artifacts"
	@rm -rf "$(DISTDIR)"

.PHONY: distclean mrproper
# Remove all build artifacts, including staged files and depfiles.
distclean mrproper: clean
	@echo "$@: removing build artifacts"
	@rm -rf "$(BUILDDIR)"

# -----------------------------------------------------------------------------
# Local test targets
# -----------------------------------------------------------------------------
.PHONY: test $(TEST_HOSTS:%=test-%)
test: $(TEST_HOSTS:%=test-%)

$(TEST_HOSTS:%=test-%): test-%: $(DISTDIR)/%.ks $(BINDIR)/test.sh
	@bash $(BINDIR)/test.sh "$*"
