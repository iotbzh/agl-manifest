---
Author: Stephane Desneux <sdx@iot.bzh>
title: How to build Chromium for AGL
---

Inside an [AGL docker container](https://download.automotivelinux.org/AGL/snapshots/sdk/docker/docker_agl_worker-generic-3.99.1.tar.xz)
use the facility tool `prepare_meta` to set up your Yocto layers:

```bash
prepare_meta -f chromium -o /xdt -l /home/devel/mirror -t qemux86-64 -e rm_work -e wipeconfig -e cleartemp
```

Source the generated Yocto environment file and launch the chromium build:

```bash
. /xdt/build/qemux86-64/agl-init-build-env
bitbake chromium-ozone-wayland
```

RPMs are then located in /xdt/build/m3ulcb/tmp/deploy/rpms

It's also possible to create an AGL image with Chromium preinstalled:

```bash
bitbake agl-demo-platform
```

The result is located in /xdt/build/m3ulcb/tmp/deploy/images/m3ulcb
