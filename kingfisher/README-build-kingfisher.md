---
Author: Stephane Desneux <sdx@iot.bzh>
title: AGL EE with Kingfisher support - Image & SDK builds
---

This document explains how to build latest [AGL] (EE) with support for Renesas [Kingfisher board].

It covers in details how to:
* install the generic AGL Worker container
* (optional) rebuild an AGL image inside the container
* install the SDK in the container and build applications with it

[AGL]:https://www.automotivelinux.org/
[Kingfisher board]:https://www.elinux.org/R-Car/Boards/Kingfisher

## Requirements

Requirements:
* recent Linux Host (openSUSE 42.3, Debian 9, Fedora 26, ...)
* recent docker (>1.10) installed. General instructions for Linux are available on the [Docker Site](https://docs.docker.com/engine/installation/linux/).

## Install AGL Docker container

### Step 1: Setup persistent workspace

Docker images are pre-configured to use a particular uid:gid to enable the use of Yocto/OpenEmbedded build system. They provide a dedicatedu ser account *devel* which belongs to uid=1664(devel) gid=1664(devel). (**Note**: password is *devel*)

The script 'create_container' used below instantiates a new container
and shares some volumes with the host:

* /xdt (the build directory inside the container) is stored in ~/ssd/xdt_$ID (specific to instance ID)
* /home/devel/mirror is stored in ~/ssd/localmirror_$ID (specific to instance ID)
* /home/devel/share => points to ~/devel/docker/share (shared by all containers)

Those shared volumes with the host need the proper permissions to be accessible from the container environment.

On the host side:
```bash
mkdir ~/ssd ~/devel
chmod a+w ~/ssd ~/devel
```

**NOTE**: to speedup builds, the folder ~/ssd should point to a fast storage (SSD or equivalent). Use symlinks or mount --bind if needed.

**NOTE 2**: To gain access from your host on files created within the container, your  host account requires to be added to group id 1664.

### Step 2: Load the Docker image "AGL Worker"

Pick the latest docker image at [this location](https://download.automotivelinux.org/AGL/snapshots/sdk/docker/)

The pre-built docker image can be used directly:

```bash
wget -O - https://download.automotivelinux.org/AGL/snapshots/sdk/docker/docker_agl_worker-generic-4.99.2.tar.xz | sudo docker load
```

If all went well, the new image is available:
```bash
docker images
REPOSITORY                                      TAG                 IMAGE ID            CREATED             SIZE
docker.automotivelinux.org/agl/worker-generic   4.99.2              a27e788ffd6b        6 days ago          1.54GB
```

**NOTE**: the Docker image for AGL Worker can be rebuilt using the scripts published here [docker-worker-generator](https://git.automotivelinux.org/AGL/docker-worker-generator/).

### Step 3: Start a new container = AGL Worker

The script 'create_container' can be used as a base template to start a new container based on the AGL Worker image.

Grab the script:
```bash
wget https://git.automotivelinux.org/AGL/docker-worker-generator/plain/contrib/create_container
chmod +x create_container
```

**WARNING** the script is just an example and may have to be tuned to your specific environment. Please review the script before executing it.

The script can create multiple containers and you'll have to pass an instance ID. You must also provide the name of the docker image to be used (usually: 'docker.automotivelinux.org/agl/worker-generic:$VERSION')

```bash
./create_container 0 docker.automotivelinux.org/agl/worker-generic:4.99.2
```

Then the container should be up and running:

```
docker ps
CONTAINER ID        IMAGE                                                  COMMAND                  CREATED             STATUS              PORTS                                                                                        NAMES
10252b46b809        docker.automotivelinux.org/agl/worker-generic:4.99.2   "/usr/bin/wait_for..."   3 minutes ago       Up 3 minutes        0.0.0.0:8000->8000/tcp, 0.0.0.0:69->69/udp, 0.0.0.0:10809->10809/tcp, 0.0.0.0:2222->22/tcp   agl-worker-freyr-0-sdx
```

The container is a standard Debian Stretch and is very close to a full VM, with systemd, ssh etc. In particular, you can install extra packages using 'apt-get install' or connect to the container through ssh on port 2222+[InstanceID].

Example:
```
$ ssh -p 2222 devel@localhost
Warning: Permanently added '[localhost]:2222' (ECDSA) to the list of known hosts.
Linux agl-worker-freyr-0-sdx 4.4.87-25-default #1 SMP Wed Sep 13 07:19:13 UTC 2017 (3927ef5) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Thu Dec 14 15:49:12 2017 from 172.17.0.1
[15:49:34] devel@agl-worker-freyr-0-sdx:~$ echo "I'm inside"
```

### Step 4: Adjust permissions

If may be needed to adjust permissions to let the user 'devel' access external volumes.

Log into the container and run the following commands:
```
ssh -p 2222 devel@localhost
sudo chown -R devel:devel /home/devel /xdt
```

### Step 5: Container life

To stop the container:
```
docker stop agl-worker-$(hostname)-0
```

To start it again:
```
docker start agl-worker-$(hostname)-0
```

To remove it:
```
docker rm agl-worker-$(hostname)-0
``` 
**NOTE**: don't forget that external volumes are not removed. You may need to clear them manually. But on the other hand, it's convenient if a new container is created: persistent data will be there.

## Build AGL EE for Kingfisher

Foreword: this section is for people who need to rebuild the AGL image from scratch. If developping applications on top of AGL, the recommended way is to grab a binary image and to install the SDK in the container (see next chapter). This allows to skip the build step which can be long.

The standard procedure to build AGL is detailed [here](http://docs.iot.bzh/docs/getting_started/en/dev/reference/machines/R-Car-Starter-Kit-gen3.html) and can be used to build AGL for Renesas Gen3 boards.

However, IoT.bzh also maintains an alternative procedure which leads to the same results while offering more freedom to add extra components or doing early integration more easily.

Except when mentioned, all commands should be run inside the docker container using the user 'devel'.

### Download Renesas proprietary drivers

Create a directory to store Renesas drivers:

```
mkdir ~/renesas
```

Download the 2 zip files located [at this location](https://www.renesas.com/en-us/solutions/automotive/rcar-demoboard-2.html) and save them in the previous directory.

### The tool 'prepare_meta'

The tool 'prepare_meta' is used to prepare the build environment. It will:
* clone Yocto layers required for building (as 'repo init' does)
* synchronize any download/sstate-cache mirror if available (to gain some build time)
* run the 'aglsetup.sh' script (normally run manually to adjust AGL features)

Check if prepare_meta is up to date by upgrading it:
```
prepare_meta -u
```

Also create a mirror directory that could be used later as a build cache:
```
mkdir -p /home/devel/mirror
```

### Prepare for Kingfisher build

Run the following command line:
```
prepare_meta -f kingfisher -o /xdt -l /home/devel/mirror/ -e wipeconfig -e cleartemp -e rm_work -t m3ulcb -p /home/devel/renesas/ agl-devel agl-netboot agl-appfw-smack agl-demo agl-localdev agl-audio-4a-framework agl-hmi-framework
```

After that, all required Yocto layers should be stored in /xdt/meta:
```
$ ls -l /xdt/meta/
total 64
drwxr-xr-x 14 devel devel 4096 Dec 13 13:55 agl-manifest
drwxr-xr-x 11 devel devel 4096 Dec 13 11:27 meta-agl
drwxr-xr-x 23 devel devel 4096 Dec 13 11:28 meta-agl-demo
drwxr-xr-x  9 devel devel 4096 Dec 13 11:28 meta-agl-devel
drwxr-xr-x  4 devel devel 4096 Dec 13 11:28 meta-agl-extra
drwxr-xr-x  9 devel devel 4096 Sep 17 20:52 meta-intel
drwxr-xr-x  7 devel devel 4096 Sep 17 20:52 meta-intel-iot-security
drwxr-xr-x  7 devel devel 4096 Sep 17 17:49 meta-oic
drwxr-xr-x 18 devel devel 4096 Sep 17 19:43 meta-openembedded
drwxr-xr-x 12 devel devel 4096 Sep 17 20:52 meta-qt5
drwxr-xr-x 16 devel devel 4096 Dec 13 11:28 meta-raspberrypi
drwxr-xr-x  4 devel devel 4096 Dec 12 18:39 meta-rcar
drwxr-xr-x  7 devel devel 4096 Aug 21 18:27 meta-renesas
drwxr-xr-x  4 devel devel 4096 Dec 14 14:30 meta-renesas-rcar-gen3
drwxr-xr-x  7 devel devel 4096 Mar 29  2017 meta-security-isafw
drwxr-xr-x 12 devel devel 4096 Dec 13 17:24 poky
```

### Run the build

Source the environment file for build:

```
source /xdt/build/m3ulcb/agl-init-build-env
```

Then run bitbake to build the "Cross SDK" image (this will produce a SDK):
```
bitbake agl-demo-platform-crosssdk
```

For a "normal" image, simply use 'agl-demo-platform'.

When the build is over, the resulting files can be found in /xdt/build/m3ulcb/tmp/deploy:
```
$ ls -l /xdt/build/m3ulcb/tmp/deploy/
total 48
drwxr-xr-x   3 devel devel  4096 Dec 14 14:31 images
drwxr-xr-x 760 devel devel 32768 Dec 14 14:44 licenses
drwxr-xr-x   6 devel devel  4096 Dec 14 14:48 rpm
drwxr-xr-x   2 devel devel  4096 Dec 14 14:51 sdk
```

### Save download dir and sstate-cache for future use

If you're satisfied with the build, you can save some directories to speed up next builds:

```
rsync -a --delete /xds/downloads/ ~/mirror/downloads/
rsync -a --delete /xds/sstate-cache/ ~/mirror/sstate-cache/
```

Next time, when prepare_meta will be run, it will copy the two reference folders located in $HOME/mirror into the build directory /xdt
prepare_meta

### Create a SD card image

In recent version of AGL, the WIC imager is used to create raw images. So you should find these files:

```
cd /xdt/build/m3ulcb/tmp/deploy/images/
ls *wic.xz
agl-demo-platform-crosssdk-m3ulcb-20171214133111.rootfs.wic.xz
agl-demo-platform-crosssdk-m3ulcb.wic.xz
```

### Create a SD card image (old method, deprecated)

You can still create a SDcard image using a script named 'mksdcard': it is available in the container for that purpose.

Go into the deploy folder and run it to create a raw image (last argument specifies the image size in Gigabytes)
```
cd /xdt/build/m3ulcb/tmp/deploy/images/
mksdcard agl-demo-platform-crosssdk-m3ulcb-*.rootfs.tar.xz . 4
```

Then you can follow this [guide to flash an image on SDcard](README-flashimage.html).

## Using AGL SDK to build applications

### Step 1: install the AGL SDK

Get the SDK installed from a previous build or download it from the web.

Case 1: you built your own image - in this case, you have the SDK installer in the container:
```
ls -l /xdt/build/m3ulcb/tmp/deploy/sdk/
total 621268
-rw-r--r-- 1 devel devel     47752 Dec 14 14:48 poky-agl-glibc-x86_64-agl-demo-platform-crosssdk-aarch64-toolchain-4.99.3+snapshot.host.manifest
-rwxr-xr-x 1 devel devel 635882031 Dec 14 14:51 poky-agl-glibc-x86_64-agl-demo-platform-crosssdk-aarch64-toolchain-4.99.3+snapshot.sh
-rw-r--r-- 1 devel devel     83888 Dec 14 14:48 poky-agl-glibc-x86_64-agl-demo-platform-crosssdk-aarch64-toolchain-4.99.3+snapshot.target.manifest
-rw-r--r-- 1 devel devel    153926 Dec 14 14:48 poky-agl-glibc-x86_64-agl-demo-platform-crosssdk-aarch64-toolchain-4.99.3+snapshot.testdata.json
```

Case  2: grab it from the web at [this address](sdk/):
```
wget http://iot.bzh/download/public/2017/Kingfisher/latest/sdk/poky-agl[VERSION].sh
```

Then, install the SDK using the 'install_sdk' script available in the container:
```
install_sdk ./poky-agl-glibc-*.sh
```

### Step 2: build your application

First, you must source the SDK environment you wish to use (you MUST repeat this step each time you open a new shell):

```bash
source /xdt/sdk/environment-setup-<your_target>
```

You're then ready to go: get the sources, run the builds ...

For example, for typical AGL demos:
```bash
git clone <application git repo>;
cd <your app>;
cmake; make; make package;
```
