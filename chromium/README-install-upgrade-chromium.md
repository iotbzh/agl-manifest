---
Author: Stephane Desneux <sdx@iot.bzh>
title: Install or upgrade Chromium on AGL/M3 through RPMs
---

## Installation

Log into the board through ssh or console, then install RPMs with dnf:

(replace xxxxxxxx by proper revision)

```bash
for x in \
	http://iot.bzh/download/public/2018/Chromium/latest/packages/aarch64/chromium-ozone-wayland-xxxxxxxxxxxxxxxxxxxxxxxxxxxx-r0.aarch64.rpm \
	http://iot.bzh/download/public/2018/Chromium/latest/packages/aarch64/chromium-ozone-wayland-chromedriver-xxxxxxxxxxxxxxxxxxxxxxxxxxxx-r0.aarch64.rpm \
	http://iot.bzh/download/public/2018/Chromium/latest/packages/noarch/hicolor-icon-theme-xxxx-r0.noarch.rpm \
	; do wget $x; done; dnf install *.rpm
```


## Removal

Run:

```bash
dnf remove chromium-ozone-wayland hicolor-icon-theme
```

## Upgrade

Remove, then reinstall:

```bash
dnf remove ...
...
dnf install ...
...
```
