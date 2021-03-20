
# Path to Wesnoth's wmlxgettext tool (should be the rewritten version from
# 1.13.x and later).
WMLXGETTEXT ?= wmlxgettext

# Path to pocheck
POCHECK ?= ./pocheck

# Path to the add-ons root. It should contain directories matching the names
# of the add-on translation directories found in this repository, so that the
# WML tools can read Lua and WML files from them.
ADDONS_PREFIX ?= ..

TRANSLATION_THRESHOLD = 80

SOURCES = \
	Invasion_from_the_Unknown \
	After_the_Storm \
	Naia

MANIFESTS := $(foreach dir,$(SOURCES),$(dir)/$(dir).manifest)
POTS      := $(foreach dir,$(SOURCES),$(dir)/wesnoth-$(dir).pot)
MOS       := $(foreach dir,$(SOURCES),$(patsubst %.po,%.mo,$(wildcard $(dir)/*.po)))

all: po-update

pot-update: $(MANIFESTS) $(POTS)

%.manifest: FORCE
	@( cd $(ADDONS_PREFIX)/`basename $*` && git describe --long ) > $@

%.pot: FORCE
	@echo "    POT     `basename $@`"
	@$(WMLXGETTEXT) --recursive --warnall --directory=$(ADDONS_PREFIX)/`dirname $*` --domain `basename $*` --package-version `cat $(ADDONS_PREFIX)/$$(dirname $*)/dist/VERSION` -o $@
	@msgfmt --statistics -o /dev/null $@ 2>&1 | sed -E 's/^.*\s([0-9]+)\s.*$$/            \1 strings/'

po-update: $(MOS)

%.po: FORCE
	@echo "    UPD     `basename $@` [wesnoth-`dirname $@`]"
	@msgmerge -q $@ $(dir $@)wesnoth-`dirname $@`.pot > $@.tmp
	@mv -f $@.tmp $@

%.mo: %.po
	@echo "    FMT     `basename $@` [wesnoth-`dirname $@`]"
	@msgfmt --statistics -o $@ $*.po

install: po-update
	@for s in $(SOURCES); do for mo in $$s/*.mo; do \
		locale="`basename -s .mo $$mo`"; \
		target_dir="$(ADDONS_PREFIX)/$$s/translations/$$locale/LC_MESSAGES"; \
		target_mo="$$target_dir/wesnoth-$$s.mo"; \
		mkdir -p "$$target_dir"; \
		echo "    INSTALL $$target_mo"; \
		perc="`$(POCHECK) $$s/$$locale.po`"; \
		if test $$? && test $$perc -lt $(TRANSLATION_THRESHOLD); then \
			echo "*** Translation below threshold ($$perc%), removing from target..."; \
			rm -f "$$target_mo"; \
			continue; \
		fi; \
		cp -f "$$mo" "$$target_mo"; \
		pbl="$$s/$$locale.pbltrans"; \
		target_pbl="$(ADDONS_PREFIX)/$$s/translations/$$locale.pbltrans"; \
		if test -e "$$pbl"; then \
			echo "    INSTALL $$target_pbl"; \
			cp -f "$$pbl" "$$target_pbl"; \
		fi; \
	done; done

clean: clean-mo

clean-pot:
	find -name '*.pot' -or -name '*.manifest' -type f -print0 | xargs -0 rm -f

clean-mo:
	find \( \
	    -name '*.new' -o \
	    -name '*.tmp' -o \
	    -name '*.mo' \
	\) -type f -print0 | xargs -0 rm -f

.PHONY: FORCE
FORCE:
