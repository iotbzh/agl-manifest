# this file is loaded from bblayers.conf at build time

BBLAYERS += " \
    @METADIR@/meta-iot-agl/meta-app-framework \
    @METADIR@/meta-iot-agl/meta-agl-devkit \
    @METADIR@/meta-browser \
    @METADIR@/meta-openembedded/meta-gnome \
    "
