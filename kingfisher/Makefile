#!/usr/bin/make -f

SOURCES=$(wildcard *.md)
DOCS=$(patsubst %.md,%.html,$(SOURCES))

all:
	@echo "Targets":
	@echo " - docs: create HTML docs"

clean:
	rm -f $(DOCS)

.PHONY: docs
docs: $(DOCS)

$(DOCS): %.html: %.md
	md2html $< $@
