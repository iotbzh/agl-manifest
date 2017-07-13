# AGL build for Salvator-X

## Step 1: install docker container for builds

Follow the [quick guide](http://docs.automotivelinux.org/docs/getting_started/en/dev/#sdk-quick-setup)

For more details, check the [detailed guide here](http://docs.automotivelinux.org/docs/devguides/en/dev/)

## Step 2: prepare the build

### Proprietary drivers

Prepare the Renesas R-Car Gen3 drivers, and put them in /home/devel/mirror/proprietary-renesas-r-car/ (or another folder and ajust the command line below)

### Build caches

For better build times, you can use caches. 
After a successful build, copy some folders from /xdt to /home/devel/mirror (or another folder and adjust command line below), then reused them in successive calls to prepare_meta.

The mirror folder may contain the following subfolders:

* 'meta' for a copy of all layers (= a copy of /xdt/meta)
* 'downloads' for a copy of the download dir (= a copy of /xdt/downloads)
* 'sstate-cache' for a copy of the sstate cache (= a copy of /xdt/sstate-cache)

### Prepare environment

Run:
```
# prepare_meta -f salvator -o /xdt -l /home/devel/mirror/ -e wipeconfig -e cleartemp -e rm_work -t salvator -p /home/devel/mirror/proprietary-renesas-r-car/
```

## Step 3: run the build

```
# . /xdt/build/salvator/agl-init-build-env
# bitbake agl-demo-platform-crosssdk
```

Result should be available in '/xdt/build/salvator/tmp/deploy/images/salvator-x/'

Then the procedure using the script 'mksdcard' (available inside docker container) can be used to create a bootable SDcard. Alternatively, using netboot should also be possible using the procedure documented in meta-agl/meta-netboot.

