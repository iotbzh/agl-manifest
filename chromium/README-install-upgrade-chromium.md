---
Author: Stephane Desneux <sdx@iot.bzh>
title: Install or upgrade Chromium on AGL/M3 through RPMs
---

## Installation

Log into the board through ssh or console, then install RPMs with smart:

```bash
for x in \
	http://iot.bzh/download/public/2018/Chromium/latest/packages/aarch64/chromium-ozone-wayland-65.0.3298.0.r524623.igalia.1-r0.aarch64.rpm \
	http://iot.bzh/download/public/2018/Chromium/latest/packages/aarch64/chromium-ozone-wayland-chromedriver-65.0.3298.0.r524623.igalia.1-r0.aarch64.rpm \
	http://iot.bzh/download/public/2018/Chromium/latest/packages/noarch/hicolor-icon-theme-0.15-r0.noarch.rpm \
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
