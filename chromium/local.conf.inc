# this file is loaded from local.conf at build time

# from https://github.com/Igalia/meta-browser/wiki
CHROMIUM_GN_PATH="/xdt/meta/depot_tools"
PACKAGECONFIG_pn-chromium+="disable-api-keys-info-bar"
