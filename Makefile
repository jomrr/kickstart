# =============================================================================
# Makefile for Kickstart build system
# =============================================================================
MAKEFLAGS       += --no-builtin-rules
MAKEFLAGS       += --warn-undefined-variables
SHELL           := /usr/bin/bash
.SHELLFLAGS     := -euo pipefail -c

.DEFAULT_GOAL   := all
.DELETE_ON_ERROR:
.SECONDARY:

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
# Host inventory
# -----------------------------------------------------------------------------
HOSTS           := $(basename $(notdir $(wildcard $(HOSTSDIR)/*.ks)))
TEST_HOSTS      := $(basename $(notdir $(wildcard $(HOSTSDIR)/example*.ks)))

# -----------------------------------------------------------------------------
# Source inventory for explicit staging rules
# -----------------------------------------------------------------------------
# Collect all logical profile and snippet stage targets.
PROFILE_STAGE_FILES := $(shell find "$(PROFILESDIR)" -type f -name '*.ksi' -printf '%P\n')
SNIPPET_STAGE_FILES := $(shell find "$(SNIPPETSDIR)" -type f -name '*.ksi' -printf '%P\n')

# Resolve a logical stage file to the preferred source file.
profile_src = $(PROFILESDIR)/$(1)
snippet_src = $(SNIPPETSDIR)/$(1)

# Return the relative subdirectory of a file or an empty string for the root.
stage_subdir = $(patsubst $(CURDIR)/,,$(dir $(1)))

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
# Requested host selection for depfile inclusion
# -----------------------------------------------------------------------------
# Only include depfiles for the hosts that are actually needed.
REQUESTED_GOALS := $(if $(MAKECMDGOALS),$(MAKECMDGOALS),all)

HOSTS_FROM_HOST_GOALS      := $(filter $(HOSTS),$(REQUESTED_GOALS))
HOSTS_FROM_FLAT_GOALS      := $(patsubst flat-%,%,$(filter flat-%,$(REQUESTED_GOALS)))
HOSTS_FROM_VALIDATE_GOALS  := $(patsubst validate-%,%,$(filter validate-%,$(REQUESTED_GOALS)))
HOSTS_FROM_TEST_GOALS      := $(patsubst test-%,%,$(filter test-%,$(REQUESTED_GOALS)))

HOSTS_FROM_FLAT_SUITE      := $(if $(filter flat,$(REQUESTED_GOALS)),$(HOSTS),)
HOSTS_FROM_VALIDATE_SUITE  := $(if $(filter validate,$(REQUESTED_GOALS)),$(HOSTS),)
HOSTS_FROM_TEST_SUITE      := $(if $(filter test,$(REQUESTED_GOALS)),$(TEST_HOSTS),)

HOSTS_FROM_DIST_TARGETS    := $(patsubst $(DISTDIR)/%.ks,%,$(filter $(DISTDIR)/%.ks,$(REQUESTED_GOALS)))
HOSTS_FROM_FLAT_TARGETS    := $(patsubst $(BUILDDIR)/%/flat.ks,%,$(filter $(BUILDDIR)/%/flat.ks,$(REQUESTED_GOALS)))
HOSTS_FROM_VALIDATE_TARGETS := $(patsubst $(BUILDDIR)/%/validate.log,%,$(filter $(BUILDDIR)/%/validate.log,$(REQUESTED_GOALS)))

HOSTS_SEL := $(sort \
	$(HOSTS_FROM_HOST_GOALS) \
	$(HOSTS_FROM_FLAT_GOALS) \
	$(HOSTS_FROM_VALIDATE_GOALS) \
	$(HOSTS_FROM_TEST_GOALS) \
	$(HOSTS_FROM_FLAT_SUITE) \
	$(HOSTS_FROM_VALIDATE_SUITE) \
	$(HOSTS_FROM_TEST_SUITE) \
	$(HOSTS_FROM_DIST_TARGETS) \
	$(HOSTS_FROM_FLAT_TARGETS) \
	$(HOSTS_FROM_VALIDATE_TARGETS))

# -----------------------------------------------------------------------------
# Generated dependency fragments
# -----------------------------------------------------------------------------
# ksdeps.py derives:
# - source entry: hosts/<host>.ks
# - build root:   build/<host>
# - depfile:      build/<host>/deps.mk
# - flat target:  build/<host>/flat.ks
$(BUILDDIR)/%/deps.mk: $(HOSTSDIR)/%.ks $(BINDIR)/ksdeps.py | $(BUILDDIR)/%/
	@echo "build/$*/deps.mk: building dependencies"
	@python3 $(BINDIR)/ksdeps.py "$*"

# Include only the depfiles that are actually needed.
ifneq ($(filter clean distclean mrproper,$(REQUESTED_GOALS)),)
else
ifneq ($(strip $(HOSTS_SEL)),)
-include $(HOSTS_SEL:%=$(BUILDDIR)/%/deps.mk)
endif
endif

# -----------------------------------------------------------------------------
# Shared stage recipe
# -----------------------------------------------------------------------------
# Render only variables with the KS_ prefix.
# Existing inherited KS_* variables are cleared first so only the current
# default.env and host-specific env file contribute values.
define stage_recipe
set -a; \
for name in $$$$(compgen -A variable KS_ || true); do unset "$$$$name"; done; \
[[ -f "$(HOSTSDIR)/default.env" ]] && . "$(HOSTSDIR)/default.env"; \
[[ -f "$(HOSTSDIR)/$(1).env" ]] && . "$(HOSTSDIR)/$(1).env"; \
set +a; \
ks_names="$$$$(compgen -A variable KS_ || true)"; \
if [[ -n "$$$$ks_names" ]]; then \
	ks_vars="$$$$(printf '$$$$%s ' $$$$ks_names)"; \
	envsubst "$$$$ks_vars" < "$$<" > "$$@"; \
else \
	cp -- "$$<" "$$@"; \
fi
endef

# -----------------------------------------------------------------------------
# Host-specific staging rules
# -----------------------------------------------------------------------------
# Staging policy:
# - Prefer plain *.ksi sources.
# - Keep staging logic explicit and deterministic.
define HOST_ROOT_STAGE_RULE
HOST_ENV_DEPS_$(1) := $(HOSTSDIR)/default.env $(wildcard $(HOSTSDIR)/$(1).env)

$(BUILDDIR)/$(1)/staged/host.ks: $(HOSTSDIR)/$(1).ks $$(HOST_ENV_DEPS_$(1)) | $(BUILDDIR)/$(1)/staged/
	@echo "build/$(1)/staged/host.ks: staging host entry"
	@$(call stage_recipe,$(1))
endef

define HOST_PROFILE_STAGE_RULE
$(BUILDDIR)/$(1)/staged/profiles/$(2): $(call profile_src,$(2)) $$(HOST_ENV_DEPS_$(1)) | $(BUILDDIR)/$(1)/staged/profiles/$(call stage_subdir,$(2))
	@echo "build/$(1)/staged/profiles/$(2): staging profile"
	@$(call stage_recipe,$(1))
endef

define HOST_SNIPPET_STAGE_RULE
$(BUILDDIR)/$(1)/staged/snippets/$(2): $(call snippet_src,$(2)) $$(HOST_ENV_DEPS_$(1)) | $(BUILDDIR)/$(1)/staged/snippets/$(call stage_subdir,$(2))
	@echo "build/$(1)/staged/snippets/$(2): staging snippet"
	@$(call stage_recipe,$(1))
endef

$(foreach host,$(HOSTS),$(eval $(call HOST_ROOT_STAGE_RULE,$(host))))
$(foreach host,$(HOSTS),$(foreach file,$(PROFILE_STAGE_FILES),$(eval $(call HOST_PROFILE_STAGE_RULE,$(host),$(file)))))
$(foreach host,$(HOSTS),$(foreach file,$(SNIPPET_STAGE_FILES),$(eval $(call HOST_SNIPPET_STAGE_RULE,$(host),$(file)))))

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
$(BUILDDIR)/%/flat.ks: $(BUILDDIR)/%/deps.mk $(BUILDDIR)/%/ks.version | $(BUILDDIR)/%/
	@echo "build/$*/flat.ks: flattening kickstart"
	@ksflatten -v "$$(cat "$(BUILDDIR)/$*/ks.version")" -c $(BUILDDIR)/$*/staged/host.ks -o "$(BUILDDIR)/$*/flat.ks"
	@echo "build/$*/flat.ks: build completed."

# -----------------------------------------------------------------------------
# Validation artifact
# -----------------------------------------------------------------------------
$(BUILDDIR)/%/validate.log: $(BUILDDIR)/%/flat.ks $(BUILDDIR)/%/ks.version | $(BUILDDIR)/%/
	@echo "build/$*/validate.log: validating kickstart"
	@ksvalidator -v "$$(cat "$(BUILDDIR)/$*/ks.version")" "$<" 2>&1 1> "$@" || \
		(echo "build/$*/validate.log: validation failed" && exit 1)
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
	@echo "clean: removing dist artifacts"
	@rm -rf "$(DISTDIR)"

.PHONY: distclean mrproper
# Remove all build artifacts, including staged files and depfiles.
distclean mrproper: clean
	@echo "distclean: removing build artifacts"
	@rm -rf "$(BUILDDIR)"

# -----------------------------------------------------------------------------
# Local test targets
# -----------------------------------------------------------------------------
.PHONY: test $(TEST_HOSTS:%=test-%)
test: $(TEST_HOSTS:%=test-%)

$(TEST_HOSTS:%=test-%): test-%: $(DISTDIR)/%.ks $(BINDIR)/test.sh
	@bash $(BINDIR)/test.sh "$*"
