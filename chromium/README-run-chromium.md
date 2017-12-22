---
Author: Stephane Desneux <sdx@iot.bzh>
title: Run Chromium on AGL/M3
---

* flash SDcard with raw image (using the 'dd' commande from the conole, for example: dd if=xxxx.raw of=/dev/sdX bs=4M)
* boot the board

# Runtime setup

When board starts, you should see the usual AGL homescreen base on IVI-Shell extension.

But Chromium is not compatible with this extension so we have to revert to a more usual protocol (XDG-Shell).

Boot the board and execute the following commands from the target console:

```bash
root@m3ulcb:~# sed -i "s/ivi-shell/desktop-shell/g" /etc/xdg/weston/weston.ini

root@m3ulcb:~# for svr in HomeScreenAppFrameworkBinderAGL.service HomeScreen WindowManager.service; do systemctl --user stop $svr; systemctl --user disable $svr; done

root@m3ulcb:~# systemctl restart weston
```

# Start chrome

From the target console enter the following command to open chromium application:

```bash
/usr/bin/google-chrome --mus --touch-events=enabled --ozone-platform=wayland --no-sandbox --enable-wayland-ime --use-ime-service http://docs.iot.bzh
```


