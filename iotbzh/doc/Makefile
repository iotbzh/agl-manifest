#!/usr/bin/make -f

SOURCES=$(wildcard *.md)
DOCDEPS=$(wildcard *.mdinc)
DOCS=$(patsubst %.md,%.html,$(SOURCES))

all:
	@echo "Targets":
	@echo " - docs: create HTML docs"

clean:
	rm -f $(DOCS)

.PHONY: docs
docs: $(DOCS) $(DOCDEPS)

$(DOCS): %.html: %.md
	md2html $< $@ --toc --variable=revision:$(shell date -u +%Y%m%d_%H%M)
