# this file is loaded from local.conf at build time

# from https://github.com/Igalia/meta-browser/wiki
PACKAGECONFIG_pn-chromium+="use-egl wayland disable-api-keys-info-bar"

IMAGE_INSTALL_append = " chromium"
