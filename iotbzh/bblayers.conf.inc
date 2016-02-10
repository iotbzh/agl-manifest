# this file is loaded from bblayers.conf at build time

BBLAYERS += " \
    @METADIR@/meta-intel-iot-security/meta-security-smack \
    @METADIR@/meta-intel-iot-security/meta-security-framework \
	@METADIR@/meta-iot-agl/meta-app-framework \
    "

