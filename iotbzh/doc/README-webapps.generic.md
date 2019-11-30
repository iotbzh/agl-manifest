---
author: Stephane Desneux <sdx@iot.bzh>
title: Running webapps on AGL
---

## Step 1: build apps

Some webapps are available in the following location: https://github.com/AGL-web-applications . Other apps are also available on AGL Gerrit.

Forst, let's create the widgets:

```bash
git clone https://github.com/AGL-web-applications/webapp-samples
cd webapp-samples
make
```

This will produce a 'package' subfolder with the widgets.

## Step 2: boot the board and install the widgets

Boot the board with image provided here (see [README-flashimage](README-flashimage.html)).

Copy the files:
```bash
scp package/*.wgt root@yourboard:/tmp/
```

Then install the widgets

```bash
ssh root@yourboard
for x in /tmp/*.wgt; do afm-util install $x && rm $x; done
```
And finally reboot.

## Step 3: run the webapps

New apps should be available on the homescreen. Start the webapps as any other app.

