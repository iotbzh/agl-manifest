# this file is loaded from bblayers.conf at build time

BBLAYERS += " \
    @METADIR@/meta-iot-agl/meta-rcar-gen2 \
    @METADIR@/meta-iot-agl/meta-netboot \
    @METADIR@/meta-openembedded/meta-initramfs \
    "

