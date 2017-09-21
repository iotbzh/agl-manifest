#!/usr/bin/make -f

SOURCES=$(wildcard *.md)
DOCS=$(patsubst %.md,%.html,$(SOURCES))

SERVER=apache@vm-www:/download/public/2017/Chromium/latest/

all:
	@echo "Targets":
	@echo " - docs: create HTML docs"
	@echo " - publish: pushes the docs to $(SERVER)"

clean:
	rm -f $(DOCS)

.PHONY: docs
docs: $(DOCS)

publish: $(DOCS)
	scp $(DOCS) $(SERVER)

$(DOCS): %.html: %.md
	md2html $< $@



