# this file is loaded from local.conf at build time

OVERRIDES .= ":smack"
DISTRO_FEATURES_append = " smack dbus-cynara"

# add debug and perf tools to image
IMAGE_INSTALL_append = " \
	strace \
	ldd \
	gdb \
    perf \
    powertop \
    latencytop \
    systemtap \
"

IMAGE_INSTALL_append = " qtwebengine"
#IMAGE_INSTALL_append = " qtwebkit-examples-examples"
#IMAGE_INSTALL_append = " qtwebengine-examples"
#IMAGE_INSTALL_append = " weston-ivi-shell-config"
#PACKAGECONFIG_append_pn-qtbase = " examples"

IMAGE_CMD_TAR = "tar --xattrs-include='*'"
IMAGE_DEPENDS_tar_append = " tar-replacement-native"
EXTRANATIVEPATH += "tar-native"

