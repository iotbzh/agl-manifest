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

# Runtime setup

Boot the board and execute following commands for the target console:

```bash
root@m3ulcb:~# sed -i "s/ivi-shell/desktop-shell/g" /etc/xdg/weston/weston.ini
root@m3ulcb:~# systemctl restart weston
```

# Start chrome

```bash
 /usr/bin/google-chrome --mus --no-sandbox --start-maximized http://docs.iot.bzh
```
