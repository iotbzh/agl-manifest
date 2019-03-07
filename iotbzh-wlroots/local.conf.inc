# this file is loaded from local.conf at build time

#prevent from using ninja witch cmake -> conflict with audio recipes
OECMAKE_GENERATOR ?= "Unix Makefiles"
