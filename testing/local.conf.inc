# this file is loaded from local.conf at build time

# add debug and perf tools to image
IMAGE_INSTALL_append = " \
	strace \
	ldd \
	gdb \
    perf \
    powertop \
    latencytop \
    systemtap \
	screen \
"

#IMAGE_INSTALL_append = " qtwebengine"
# Add webkit as workaround as webengine is broken right now
#IMAGE_INSTALL_append = " qtwebkit qtwebkit-examples-examples"
#IMAGE_INSTALL_append = " qtsmarthome cinematicexperience qt5everywheredemo qt5-demo-extrafiles"
#IMAGE_INSTALL_append = " qtwebengine-examples"
#IMAGE_INSTALL_append = " weston-ivi-shell-config"
#PACKAGECONFIG_append_pn-qtbase = " examples"

##### USB tools
IMAGE_INSTALL_append = " \
	usbutils \
"

#-------------------- options for SDK ----------------------

# add eclipse debug stuff
EXTRA_IMAGE_FEATURES = "debug-tweaks eclipse-debug tools-debug tools-profile"

# disable install of debug files in SDK
# initial value: SDKIMAGE_FEATURES="dev-pkgs dbg-pkgs staticdev-pkgs"
SDKIMAGE_FEATURES="dev-pkgs"

#--------------------- security flags ------------------------
# require ../poky/meta/conf/distro/include/security_flags.inc

#--------------------- initramfs -----------------------------
IMAGE_CLASSES += "image_types_uboot"
INITRAMFS_FSTYPES = "ext4.gz.u-boot"
INITRAMFS_IMAGE = "initramfs-netboot-image"

# also build an image with ext4 format, ready for sharing with NBD
IMAGE_FSTYPES += "ext4"