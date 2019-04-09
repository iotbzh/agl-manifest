#!/usr/bin/make -f

SOURCES=$(wildcard *.md)
DOCDEPS=$(wildcard *.mdinc)
DOCS=$(patsubst %.md,%.html,$(SOURCES))

SERVER=apache@vm-www:/download/public/2019/AGL_Images/iotbzh/

all:
	@echo "Targets":
	@echo " - docs: create HTML docs"
	@echo " - publish: pushes the docs to $(SERVER)"

clean:
	rm -f $(DOCS)

.PHONY: docs
docs: $(DOCS) $(DOCDEPS)

publish: $(DOCS)
	scp $(DOCS) $(SERVER)

$(DOCS): %.html: %.md
	md2html $< $@ --toc --variable=revision:$(shell date -u +%Y%m%d_%H%M)
