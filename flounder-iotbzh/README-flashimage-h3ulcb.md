---
author: Stephane Desneux <sdx@iot.bzh>
title: Booting AGL images from SDCard
---

## Purpose

Here are the commands to run on a Linux host to create a bootable SDcard from a full image file and boot a Renesas R-Car Gen3 board (Starter Kit Premier / H3ULCB).

Requirements:

* bmaptools
* SDcard (>2GB) inserted and available at $DEVICE (/dev/sdX , replace X by appropriate letter - can be /dev/mmcblkX depending on reader device)
* the H3 board is preconfigured to boot on SDCard

### TLDR; quick instructions

* Using wget or any other tool, download the raw image (named \*.wic.xz) and the associated bmap file (\*.bmap) from [this folder](images)
    ```bash
    wget http://...../*.wic.xz
    wget http://...../*.wic.bmap
    ```
* Find your device and set DEVICE variable:
    ```bash
    $ lsblk -dli -o NAME,TYPE,HOTPLUG | grep "disk\s\+1$"
    sdk  disk       1    # <= use /dev/sdk
    $ DEVICE=/dev/sdX
    ```
* Run *bmaptool*:

    ```bash
    sudo bmaptool copy *.wic.xz $DEVICE
    ```
* Eject SDCard, insert in H3 board and turn it on.
* Enjoy! (if your firmware and uboot config are correct - see below)

#include(doc/generic-bmaptools.mdinc)

#include(doc/h3ulcb-upgrade-firmware.mdinc)

#include(doc/h3ulcb-configure-uboot.mdinc)

#include(doc/h3ulcb-boot.mdinc)

