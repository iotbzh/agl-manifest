# this file is loaded from bblayers.conf at build time

BBLAYERS += " \
    @METADIR@/meta-iot-bzh/meta-agl-devkit \
    @METADIR@/meta-iot-bzh/meta-agl-early \
    @METADIR@/meta-iot-bzh/meta-extra-apps \
    @METADIR@/meta-browser \
    @METADIR@/meta-openembedded/meta-gnome \
    "
