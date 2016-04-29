# this file is loaded from local.conf at build time (target specific)

# For running GStreamer on wayland (experimental).
IMAGE_INSTALL_append_porter = " \
    gstreamer1.0-plugins-bad-waylandsink \
"

# Additional plugins to test multimedia acceleration (experimental)
IMAGE_INSTALL_append_porter = " \
    gstreamer1.0-plugins-base-videorate \
    gstreamer1.0-plugins-base-videotestsrc \
    gstreamer1.0-plugins-base-audiotestsrc \
    gstreamer1.0-plugins-base-alsa \
    gstreamer1.0-plugins-good-autodetect \
    gstreamer1.0-plugins-good-isomp4 \
    gstreamer1.0-plugins-good-video4linux2 \
    gstreamer1.0-plugins-good-videocrop \
    gstreamer1.0-plugins-bad-asfmux \
    gstreamer1.0-plugins-bad-fbdevsink \
    gstreamer1.0-plugins-bad-faad \
    gstreamer1.0-plugins-bad-videoparsersbad \
"

# for graphics acceleration
IMAGE_INSTALL_append_porter = " \
    libegl libegl-dev libgbm-dev \
    gles-kernel-module gles-user-module \
    libdrm-tests \
    libdrm-kms \
"

# for multimedia acceleration
#
# Uncoment below if want to use multimedia acceleration
#
IMAGE_INSTALL_append_porter = " \
    packagegroup-rcar-gen2-multimedia \
    packagegroup-lcb-oss-codecs \
    alsa-utils alsa-utils-config alsa-tools \
"

# Enable Multimedia standard pkg
MACHINE_FEATURES_append = " multimedia"

