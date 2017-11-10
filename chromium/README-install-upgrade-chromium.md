---
Author: Stephane Desneux <sdx@iot.bzh>
title: Install or upgrade Chromium on AGL/M3 through RPMs
---

## Installation

Log into the board through ssh or console, then install RPMs with smart:

```bash
dnf install http://iot.bzh/download/public/2017/Chromium/latest/aarch64/chromium-20170928.r499098.git8eb8619a-dev0.aarch64.rpm
```

Typical output:

```bash
Dependencies resolved.
===================================================================================================
 Package         Arch           Version                                  Repository           Size
===================================================================================================
Installing:
 chromium        aarch64        20170928.r499098.git8eb8619a-dev0        @commandline         60 M

Transaction Summary
===================================================================================================
Install  1 Package

Total size: 60 M
Installed size: 235 M
Is this ok [y/N]: y
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Installing  : chromium-20170928.r499098.git8eb8619a-dev0.aarch64                             1/1
  Verifying   : chromium-20170928.r499098.git8eb8619a-dev0.aarch64                             1/1

Installed:
  chromium.aarch64 20170928.r499098.git8eb8619a-dev0

Complete!
```

## Removal

Run:

```bash
dnf remove chromium
```

Typical output:

```bash
Dependencies resolved.
===================================================================================================
 Package             Arch           Version                                  Repository       Size
===================================================================================================
Removing:
 chromium            aarch64        20170928.r499098.git8eb8619a-dev0        @oe-repo        235 M

Transaction Summary
===================================================================================================
Remove  2 Packages

Installed size: 235 M
Is this ok [y/N]: y
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Erasing     : chromium-20170928.r499098.git8eb8619a-dev0.aarch64                             1/1
  Verifying   : chromium-20170928.r499098.git8eb8619a-dev0.aarch64                             1/1

Removed:
  chromium.aarch64 20170928.r499098.git8eb8619a-dev0

Complete!
```

## Upgrade

Remove, then reinstall:

```bash
dnf remove chromium
...
dnf install http://iot.bzh/download/public/2017/Chromium/latest/aarch64/chromium-20170928.r499098.git8eb8619a-dev0.aarch64.rpm
...
```
