# How to build chromium

This is a simple step by step guide to build chromium for a given machine.

Inside an [AGL docker container](https://download.automotivelinux.org/AGL/snapshots/sdk/docker/docker_agl_worker-generic-3.99.1.tar.xz)
use the facility tool `prepare_meta` to set up your Yocto layers:

```bash
prepare_meta -f chromium -o /xdt -l /home/devel/mirror -t qemux86-64 -e rm_work -e wipeconfig -e cleartemp
```

Source the generated Yocto environment file and launch the chromium build:

```bash
. /xdt/build/qemux86-64/agl-init-build-env
bitbake chromium
```

# Installation

Go to your build directory and copy Chromium rpm on target board using network:

```bash
cd $AGL_TOP/build/tmp/deploy/rpm/$MACHINE
sudo scp chromium-20170606*rpm root@YOUR.TARGET.BOARD.IP:/tmp
```

From a root session on the target board install the package with:

```bash
rpm -ivh /tmp/chromium-20170606*.rpm
```
