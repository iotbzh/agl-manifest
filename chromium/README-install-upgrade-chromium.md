---
Author: Stephane Desneux <sdx@iot.bzh>
title: Install or upgrade Chromium on AGL/M3 through RPMs
---

## Installation

Log into the board through ssh or console, then install RPMs with smart:

```bash
dnf install http://iot.bzh/download/public/2017/Chromium/latest/aarch64/chromium-ozone-igalia-<VERSION>.aarch64.rpm http://iot.bzh/download/public/2017/Chromium/latest/noarch/hicolor-icon-theme-<VERSION>.aarch64.rpm
```


## Removal

Run:

```bash
dnf remove chromium-ozone-igalia hicolor-icon-theme
```

## Upgrade

Remove, then reinstall:

```bash
dnf remove ...
...
dnf install ...
...
```
