# this file is loaded from local.conf at build time

# from https://github.com/Igalia/meta-browser/wiki
PACKAGECONFIG_pn-chromium-ozone-wayland+="proprietary-codecs use-egl wayland disable-api-keys-info-bar"

DEPENDS_pn-libepoxy += "libegl"

IMAGE_INSTALL_append = " hicolor-icon-theme chromium-ozone-wayland"

# see SPEC-1037
IMAGE_FSTYPES_remove = "cpio.gz"

# workaround for libav on x86_64
LICENSE_FLAGS_WHITELIST += "commercial"
