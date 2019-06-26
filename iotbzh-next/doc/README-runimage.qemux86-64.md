---
author: Stephane Desneux <sdx@iot.bzh>
title: Running AGL qemu images
---

## Purpose

Here are the steps to run an AGL image using host qemu.

Requirements:

* download an AGL image in VMDK format (usually named agl-demo-platform-crosssdk-qemux86-64-*timestamp*.rootfs.wic.vmdk)
* have qemu-kvm installed on host machine

## Installing qemu-kvm

### RPM-based distribution

qemu-kvm is available in most distributions 

For example, on Opensuse:

```bash
sudo zypper in qemu-kvm
```

On Fedora:

```bash
sudo dnf install qemu-kvm
```

### Debian-based distribution (inc. Ubuntu)

bmap-tool is available in Debian distributions (not tested).

```bash
sudo apt-get install qemu-kvm
```

## Running Qemu

The following script my help to run AGL:

```bash
#!/bin/bash

IMAGE=${1:-agl-demo-platform-qemux86-64.vmdk}

set -x

qemu-system-x86_64 \
	-hda $IMAGE \
	-enable-kvm \
	-machine q35 \
	-m 2048 \
	-cpu kvm64 -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt \
	-show-cursor \
	-device virtio-rng-pci \
	-soundhw hda \
	-serial mon:stdio -serial null \
	-net nic -net user,hostfwd=tcp::3333-:22,hostfwd=tcp::1025-:1025 \
	-usb -usbdevice tablet \
	-vga virtio 
```

The -net directive will create a port forwarding for ssh (3333 on host, 22 on emulated system).
After the boot, you can log in through ssh on the emulated AGL using:

```bash
$ ssh -p 3333 root@localhost
```

