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

root@m3ulcb:~# systemctl restart weston
```

# Start chrome

From the target console enter the following command to open chromium application:

```bash
/usr/bin/google-chrome \
	--no-sandbox \
	http://docs.iot.bzh
```

Other useful options:

* --use-ime-service 
* --ignore-gpu-blacklist
* --touch-events=enabled
* --enable-wayland-ime : Enable Wayland IME
* --autoplay-policy=no-user-gesture-required : Enable movie autoplay
* --disable-infobars : Disable info bars
* --app=${URL} : Application mode
* --kiosk : Kiosk mode
* --window-size=1920,1080 : Set window size
* --start-maximized : Window maximize
