#!/usr/bin/make -f

SOURCES=$(wildcard *.md)
DOCS=$(patsubst %.md,%.html,$(SOURCES))

all: docs

clean:
	rm -f $(DOCS)

.PHONY: docs
docs: $(DOCS)

$(DOCS): %.html: %.md
	md2html $< $@


