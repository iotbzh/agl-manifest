---
Author: Stephane Desneux <sdx@iot.bzh>
title: Install or upgrade Chromium on AGL/M3 through RPMs
---

## Installation

Log into the board through ssh or console, then install RPMs with smart:

```bash
# smart install \
	http://iot.bzh/download/public/2017/Chromium/latest/aarch64/nss-3.26-r0.aarch64.rpm \
	http://iot.bzh/download/public/2017/Chromium/latest/aarch64/chromium-20170916.r500876.gitb34a859-dev0.aarch64.rpm
```

Typical output:
```log
Fetching packages...                                                                                                                                   
-> http://iot.bzh/download/public/2017/Chromium/latest/aarch64/chromium-20170916.r500876.gitb34a859-dev0.aarch64.rpm                                   
-> http://iot.bzh/download/public/2017/Chromium/latest/aarch64/nss-3.26-r0.aarch64.rpm                                                                 
nss-3.26-r0.aarch64.rpm           ###################################### [ 50%]
chromium-20170916.r500876.gitb34a859-dev0.aarch64.rpm  ################# [100%]

Loading cache...
Updating cache...                 ###################################### [100%]

Computing transaction...

Installing packages (2):
  chromium-20170916.r500876.gitb34a859-dev0@aarch64         nss-3.26-r0@aarch64                                                        

94.3MB of package files are needed. 251.8MB will be used.

Confirm changes? (Y/n): 

                                                                                                                                                       
Committing transaction...
Preparing...                      ###################################### [  0%]
   1:Installing nss               ###################################### [ 50%]
   2:Installing chromium          ###################################### [100%]
```

## Removal

Run: 

```bash
# smart remove nss-3.26
```

Typical output:
```
Loading cache...
Updating cache...                 ###################################### [100%]

Computing transaction...

Removing packages (2):
  chromium-20170916.r500876.gitb34a859-dev0@aarch64         nss-3.26-r0@aarch64                                                        

251.8MB will be freed.

Confirm changes? (Y/n): 

Committing transaction...                                                                                                                              
Preparing...                      ###################################### [  0%]
   1:Removing nss                 ###################################### [ 50%]
   2:Removing chromium            ###################################### [100%]
```

## Upgrade

Remove, then reinstall:

```bash
# smart remove nss-3.26
...
# smart install \
	http://iot.bzh/download/public/2017/Chromium/latest/aarch64/nss-3.26-r0.aarch64.rpm
	http://iot.bzh/download/public/2017/Chromium/latest/aarch64/chromium-20170916.r500876.gitb34a859-dev0.aarch64.rpm
...
```

