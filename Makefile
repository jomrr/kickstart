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
HOSTSDIR        := $(CURDIR)/hosts
PROFILESDIR     := $(CURDIR)/profiles
SNIPPETSDIR     := $(CURDIR)/snippets
BUILDDIR        := $(CURDIR)/build
DISTDIR         := $(CURDIR)/dist

# -----------------------------------------------------------------------------
# Inventory
# -----------------------------------------------------------------------------
PROFILES	:= $(shell find "$(PROFILESDIR)" -type f | sort)
SNIPPETS	:= $(shell find "$(SNIPPETSDIR)" -type f | sort)
HOSTS           := $(basename $(notdir $(wildcard $(HOSTSDIR)/*.ks)))
TEST_HOSTS      := $(basename $(notdir $(wildcard $(HOSTSDIR)/example*.ks)))

# -----------------------------------------------------------------------------
# Makefile settings
# -----------------------------------------------------------------------------
.DEFAULT_GOAL   := all
.DELETE_ON_ERROR:
.PRECIOUS: $(BUILDDIR)/%.ksv $(BUILDDIR)/%.ks $(DISTDIR)/%.ks

# -----------------------------------------------------------------------------
# Generic directory rule
# -----------------------------------------------------------------------------
%/:
	@mkdir -p "$@"

# -----------------------------------------------------------------------------
# Main targets
# -----------------------------------------------------------------------------

.PHONY: all
# Build all published Kickstart files.
all: $(HOSTS:%=$(DISTDIR)/%.ks)

.PHONY: $(HOSTS)
# Build one published Kickstart file.
$(HOSTS): %: $(DISTDIR)/%.ks

# -----------------------------------------------------------------------------
# Publish Kickstart artifacts
# -----------------------------------------------------------------------------

# Generate per-host version file.
$(BUILDDIR)/%.ksv: $(HOSTSDIR)/%.ks | $(BUILDDIR)/
	@echo "build/$*.ksv: generating version file."
	@version="$$(sed -nE 's/^#version[[:space:]]*=[[:space:]]*([^[:space:]]+).*$$/\1/p' "$<" | \
	head -n 1)"; \
	printf '%s\n' "$${version:-DEVEL}" > "$@"
	@echo "build/$*.ksv: version file with $$(cat "$@") generated."

# Generate flattened Kickstart file.
$(BUILDDIR)/%.ks: $(HOSTSDIR)/%.ks $(BUILDDIR)/%.ksv \
                  $(HOSTSDIR)/default.env $(wildcard $(HOSTSDIR)/%.env) \
                  $(PROFILES) $(SNIPPETS) | $(BUILDDIR)/
	@echo "build/$*.ks: building flattened kickstart."
	@set -a; . hosts/default.env; \
		[[ -f hosts/$*.env ]] && . hosts/$*.env; \
		set +a; \
		ksflatten -c hosts/$*.ks -v "$$(cat "$(BUILDDIR)/$*.ksv")" | \
		envsubst "$$(printf '$$%s ' $$(compgen -A variable KS_))" > "$@"
	@echo "build/$*.ks: build completed."

# Publish the generated Kickstart file, with optional validation.
$(DISTDIR)/%.ks: $(BUILDDIR)/%.ks \
		 $(if $(filter 1,$(VALIDATE)),$(BUILDDIR)/%.ksv) | $(DISTDIR)/
	@[[ "$(VALIDATE)" != "1" ]] || \
		ksvalidator -v "$$(cat "$(BUILDDIR)/$*.ksv")" "$<" > /dev/null
	@cp "$<" "$@"
	@echo "dist/$*.ks: published successfully."

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
.PHONY: clean
# Remove published artifacts.
clean:
	@echo "$@: removing dist artifacts."
	@rm -rf "$(DISTDIR)"

.PHONY: distclean mrproper
# Remove published artifacts and any generated dependency fragments.
distclean mrproper: clean
	@echo "$@: removing dependency artifacts."
	@rm -rf "$(BUILDDIR)"

# -----------------------------------------------------------------------------
# Local test targets
# -----------------------------------------------------------------------------
.PHONY: test $(TEST_HOSTS:%=test-%)
test: $(TEST_HOSTS:%=test-%)

$(TEST_HOSTS:%=test-%): test-%: $(DISTDIR)/%.ks bin/test.sh
	@bash bin/test.sh "$*"
