# =============================================================================
# Makefile for kickstart build system
# =============================================================================
MAKEFLAGS	+= --no-builtin-rules
MAKEFLAGS	+= --warn-undefined-variables
SHELL		:= /usr/bin/bash
.SHELLFLAGS	:= -euo pipefail -c

# -----------------------------------------------------------------------------
# User-configurable variables
# -----------------------------------------------------------------------------
# set to 1 to enable ksvalidator validation of generated kickstart files
VALIDATE	?= 1

# -----------------------------------------------------------------------------
# Host inventory as env files
# -----------------------------------------------------------------------------
HOSTS		:= $(basename $(notdir $(wildcard hosts/*.ks)))

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------
BUILDDIR	:= $(CURDIR)/build
DISTDIR		:= $(CURDIR)/dist

# -----------------------------------------------------------------------------
# Targets
# -----------------------------------------------------------------------------

# create build and dist directories
$(DISTDIR) \
$(BUILDDIR) \
$(BUILDDIR)/hosts \
$(BUILDDIR)/profiles \
$(BUILDDIR)/snippets \
$(BUILDDIR)/deps:
	@mkdir -p "$@"

.PHONY: all
# build all kickstart files
all: $(HOSTS:%=$(DISTDIR)/%.ks)

# build kickstart file for host
.PHONY: $(HOSTS)
$(HOSTS): %: $(DISTDIR)/%.ks

# host entry staged per host
$(BUILDDIR)/hosts/%.ks: $(CURDIR)/hosts/%.ks | $(BUILDDIR)/hosts
	@echo "build/hosts/$*.ks: staging host entry"
	@cp -f "$<" "$@"

# shared profiles staged globally
$(BUILDDIR)/profiles/%.ks: $(CURDIR)/profiles/%.ks | $(BUILDDIR)/profiles
	@echo "build/profiles/$*.ks: staging profile"
	@cp -f "$<" "$@"

# shared snippets staged globally
$(BUILDDIR)/snippets/%.ks: $(CURDIR)/snippets/%.ks | $(BUILDDIR)/snippets
	@echo "build/snippets/$*.ks: staging snippet"
	@cp -f "$<" "$@"

$(BUILDDIR)/deps/%.mk: $(CURDIR)/hosts/%.ks $(CURDIR)/bin/ksdeps.py \
	| $(BUILDDIR)/deps
	@echo "build/deps/$*.mk: building dependencies"
	@python3 bin/ksdeps.py \
		--profile  "hosts/$*.ks" \
		--target   "$(DISTDIR)/$*.ks" \
		--out-mk   "$@.tmp" \
		--cwd      "$(CURDIR)" \
		--build-dir "$(BUILDDIR)"
	@{ test -f "$@" && cmp -s "$@.tmp" "$@"; } \
		&& rm -f "$@.tmp" \
		|| mv -f "$@.tmp" "$@"
	@touch "$@"

# select hosts to build based on make goals
GOALS := $(filter $(HOSTS) all,$(MAKECMDGOALS))
HOSTS_SEL := $(if $(filter all,$(GOALS)),$(HOSTS),$(filter $(HOSTS),$(GOALS)))

# include host dependency makefiles
ifneq ($(filter clean distclean,$(MAKECMDGOALS)),clean distclean)
include $(HOSTS_SEL:%=$(BUILDDIR)/deps/%.mk)
endif

# rule to build kickstart file from host env file and profile template
$(DISTDIR)/%.ks: $(BUILDDIR)/deps/%.mk | $(DISTDIR)
	@echo "dist/$*.ks: building flattened kickstart"
	@python3 bin/kswrap.py \
		--in  "$(BUILDDIR)/hosts/$*.ks" \
		--out "$@" \
		$(if $(filter 1,$(VALIDATE)),--validate,)
	@echo "dist/$*.ks: build completed."

.PHONY: clean
# remove build artifacts, keep build/ and deps if you add any later
clean:
	@echo "clean: removing dist artifacts"
	@rm -rf "$(DISTDIR)"

.PHONY: distclean
# remove everything that is generated
distclean: clean
	@echo "distclean: removing build artifacts"
	@rm -rf "$(BUILDDIR)"