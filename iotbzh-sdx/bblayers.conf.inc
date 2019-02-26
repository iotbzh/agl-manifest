# this file is loaded from bblayers.conf at build time
##

BBLAYERS += " \
    @METADIR@/meta-iot-internal/meta-agl-sandbox \
    @METADIR@/meta-browser \
    @METADIR@/meta-rust \
    "

