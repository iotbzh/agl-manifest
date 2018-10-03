#!/bin/bash

################################################################################

# The MIT License (MIT)
#
# Copyright (c) 2016 Stéphane Desneux <sdx@iot.bzh>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

################################################################################

# load libzh (loads /etc/xdtrc)
. $(dirname $BASH_SOURCE)/libzh.sh

# trap and exit on error
trap 'rc=$?; error "command failed"; exit $rc;' ERR

# ---------------- configuration ------------------------------------------

# specify config file
CONFIG_FILE=${SNAPTOOL_CONF:-$XDT_DIR/snaptool.conf}

declare -A MIRROR RESOURCES BUILD DEPLOY
FOLDERS="MIRROR RESOURCES BUILD DEPLOY"

function __configure() {
	# create config file if needed
	[[ ! -f $CONFIG_FILE ]] && {
		info "Creating config file $CONFIG_FILE"
		touch $CONFIG_FILE || fatal "Unable to create config file $CONFIG_FILE"
		cat <<'EOF' >$CONFIG_FILE
# configuration file for snaptool
# see https://github.com/iotbzh/agl-manifest/tree/master/scripts for more information

# how mirror can be mounted/unmounted and accessed locally
MIRROR[path]=$HOME/mirror
MIRROR[mount_init]="[[ ! -f ~/.ssh/id_rsa ]] && ssh-keygen -N '' -f ~/.ssh/id_rsa; ssh-copy-id -p 2222 devel@thor"
MIRROR[mount]="sshfs -p 2222 devel@thor:/home/devel/mirror -o nonempty ${MIRROR[path]}"
MIRROR[umount]="fusermount -u ${MIRROR[path]}"

RESOURCES[path]=$HOME/mirror/proprietary-renesas-r-car
RESOURCES[mount]=
RESOURCES[umount]=

# temp build folder
BUILD[path]=$XDT_DIR
BUILD[mount]=
BUILD[umount]=
BUILD[targets]=agl-demo-platform-crosssdk

# deployment folder
DEPLOY[path]=$XDT_DIR/deploy
DEPLOY[mount]=
DEPLOY[umount]=
EOF
	}
	[[ ! -f $CONFIG_FILE ]] && fatal "Unable to find config file $CONFIG_FILE"

	# load configuration file
	debug "Loading config file $CONFIG_FILE"
	. $CONFIG_FILE

	[[ -z "${MIRROR[path]}" ]] && fatal "Invalid value for MIRROR[path] in $CONFIG_FILE"
	[[ -z "${RESOURCES[path]}" ]] && fatal "Invalid value for RESOURCES[path] in $CONFIG_FILE"
	[[ -z "${BUILD[path]}" ]] && fatal "Invalid value for BUILD[path] in $CONFIG_FILE"
	[[ -z "${DEPLOY[path]}" ]] && fatal "Invalid value for DEPLOY[path] in $CONFIG_FILE"

	return 0
}

__configure

# --------------------------- retention policy in deploy dir -------------------

# compute dates to keep
function compute_retention_dates() {
	function dt() {
		date --utc +%Y%m%d -d "$@"
	}

	local now=$(dt "${1:-now}")
	
	function previous_sunday() {
		local cur=$1 dow
		while true; do
			dow=$(date --utc +%u -d $cur)
			[[ $dow == 7 ]] && break
			cur=$(dt "$cur -1 day")
		done
		echo $cur
	}

	function last_sunday_previous_month() {
		local cur=$1
		cur=$(date --utc +%Y%m01 -d $cur)
		cur=$(dt "$cur -1 day")
		cur=$(previous_sunday $cur)
		echo $cur
	}

	function last_sunday_previous_quarter() {
		local cur=$1 month qmonth
		month=$(date --utc +%m -d $cur)
		month=${month#0}
		qmonth=$(printf "%02d" $(( month-(month-1)%3 )) ) # first month of the quarter
		cur=$(date --utc +%Y${qmonth}01 -d $cur) # first day of the quarter
		cur=$(dt "$cur -1 day")
		cur=$(previous_sunday $cur)
		echo $cur
	}

	# build the list of accepted dates
	local dates

	# last n days
	dates=$now
	for x in $(seq 2 $DAYS); do 
		now=$(dt "$now -1 day")
		dates="$dates $now"
	done

	# find preceding sunday and take n weeks
	now=$(dt "$now -1 day")
	now=$(previous_sunday $now)
	dates="$dates $now"
	for x in $(seq 1 $WEEKS); do 
		now=$(dt "$now -1 week")
		dates="$dates $now"
	done

	# find last sunday of each month in previous months
	now=$(last_sunday_previous_month $now)
	dates="$dates $now"
	for x in $(seq 1 $MONTHS); do 
		now=$(last_sunday_previous_month $now)
		dates="$dates $now"
	done

	# find last sunday of each quarter in previous quarters
	now=$(last_sunday_previous_quarter $now)
	dates="$dates $now"
	for x in $(seq 1 $QUARTERS); do 
		now=$(last_sunday_previous_quarter $now)
		dates="$dates $now"
	done

	echo $dates
}

function find_snapshots() {
	local dir=$1
	local pattern=$2
	debug "Finding snapshots in $dir matching $pattern"

	pushd $dir &>/dev/null || fatal "Invalid directory $dir" #{
		# list all objects matching pattern and beeing a folder
		for x in $(find . -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
			[[ "$x" =~ $pattern ]] && echo $x
		done
	popd &>/dev/null #}
}

function simulate_gc() {
	local tmpdir=/tmp/simulate_gc
	local prefix=Snapshot_
	rm -rf $tmpdir
	mkdir -p $tmpdir
	for day in {0..600}; do
		now=$(date --utc +%Y%m%d -d "20170101 +$day days")
		mkdir $tmpdir/${prefix}$now
		keepdates=$(compute_retention_dates $now)
		snapshots=$(find_snapshots $tmpdir "^$prefix.*$")
		echo -n $now: $(wc -w <<<$snapshots) snapshots.
		for x in $(find_snapshots $tmpdir "^${prefix}_.*$"); do
			sdt=${x#$prefix}
			grep -q $sdt <<<$keepdates || {
				echo -n " -$x"
				rmdir $tmpdir/$x
			}
		done
		echo
	done
}

function get_snapshots_age() {
	local tmpdir=/tmp/simulate_gc
	local prefix=Snapshot_
	local snapshots=$(find_snapshots $tmpdir "^$prefix.*$")

	local tsnow=$(date --utc +%s -d "${1:-now}")
	local sdt age days hours
	for x in $snapshots; do
		sdt=${x#$prefix}
		age=$(( ($tsnow - $(date --utc +%s -d $sdt))/3600 ))
		hours=$(( age % 24 ))
		days=$(( age / 24 )) # in days
		printf "%s %03dd.%02dh\n" $x $days $hours
	done
}


################ TODO: FIXME - OLD CODE

function commandBAD_gcdebug() {
	debug "Retention dates:"
	for x in $(compute_retention_dates "$@"); do
		debug $x $(date --utc "+%a" -d $x)
	done
	#simulate
	#get_snapshots_age "$@"
}

# ------------------------ ops on folders -----------------------------------------

function folders_check() {
	for x in $FOLDERS; do
		typeset -n folder=$x
		[[ ! -d ${folder[path]} ]] && { error "Directory '${folder[path]}' ($x) doesn't exist"; return 1; }
		debug "Directory ${x[path]} is available"
	done
	return 0
}

function folders_init() {

	info "Initializing folders..."
	for x in $FOLDERS; do
		typeset -n folder=$x
		mkdir -p ${folder[path]}
		[[ -n "${folder[mount_init]}" ]] && {
			info "Running mount_init command for $x: ${folder[mount_init]}"
			eval ${folder[mount_init]} || fatal "mount_init failed"
		} || debug "Nothing to do for $x"
	done
	debug "folders_init done"
}

function folders_mount() {
	info "Mounting folders..."
	for x in $FOLDERS; do
		typeset -n folder=$x
		mkdir -p ${folder[path]}
		[[ -n "${folder[mount]}" ]] && {
			info "Running mount command for $x: ${folder[mount]}"
			eval ${folder[mount]} || fatal "mount failed"
		} || debug "Nothing to do for $x"
	done
	debug "folders_mount done"
}

function folders_umount() {
	info "Unmounting folders..."
	for x in $FOLDERS; do
		typeset -n folder=$x
		[[ -n "${folder[umount]}" ]] && {
			info "Running umount command for $x: ${folder[umount]}"
			eval ${folder[umount]}
		} || debug "Nothing to do for $x"
	done
	info "folders_umount done"
}

function get_setupfile() {
	echo ${BUILD[path]}/snaptool-setup.conf
}

# ----------------------------------------------------------------------

function command_clean() {
	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options] 
   options:
      -h|--help   : get this help
EOF
	}

	local opts="-o h --long help" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; _usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-h|--help) __usage; return 0;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	folders_umount

	rm -f $(get_setupfile)
}

function command_prepare() {
	local init flavour machine

	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options] -- [extra features]
    options:
        -i|--init           : run initialization steps
        -f|--flavour <name> : flavour to build
        -m|--machine <name> : machine to build for
        -h|--help           : get this help
   [extra features] are passed to prepare_meta
EOF
	}

	local opts="-o i,f:,m:,h --long init,flavour:,machine:,help" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; _usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-i|--init) init=1; shift;;
			-f|--flavour) flavour=$2; shift 2;;
			-m|--machine) machine=$2; shift 2;;
			-h|--help) __usage; return 0;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	[[ -z "$flavour" ]] && fatal "flavour not specified"
	[[ -z "$machine" ]] && fatal "machine not specified"
	info "Prepare for $machine flavour $flavour"

	command_clean

	[[ "$init" == 1 ]] && folders_init
	folders_mount

	# run prepare_meta
	local opts="-t $machine -f $flavour -o ${BUILD[path]} -l ${MIRROR[path]} -e wipeconfig -e cleartemp -e rm_work -p ${RESOURCES[path]}"
	local ts0=$(date +%s)
	info "Running: prepare_meta $opts"

	prepare_meta $opts

	# generate config file to be sourced by other steps (build; deploy ...)
	local ts=$(( $(date +%s) - ts0))
	cat <<EOF >$(get_setupfile)
# file generated by $(basename $0)
#
# ---------- prepare at $(date -u -Iseconds -d @$ts0) -------
# prepare_meta run as:
#    prepare_meta $opts
HOST="$(id -un)@$(hostname -f)"
MACHINE=$machine
FLAVOUR=$flavour
PREPARE_TS="$ts0"
PREPARE_TIME="$(date +%H:%M:%S -u -d @$ts)"
BB_BUILD=${BUILD[path]}/build/$machine
EOF

	# remote dirs are not needed anymore
	folders_umount
}

function command_build() {
	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options] [build_targets]
   options:
      -h|--help   : get this help

   build_targets:
      list of targets to pass to bitbake
      default is specified in configuration file $CONFIG_FILE
	  current value: ${BUILD[targets]}

EOF
	}

	local opts="-o h --long help" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; _usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-h|--help) __usage; return 0;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	setupfile=$(get_setupfile)
	[[ ! -f $setupfile ]] && fatal "Setup file $setupfile not found. Does '$MYNAME prepare' has been run ?"
	. $setupfile

	[[ -z "$MACHINE" ]] && fatal "Invalid machine name. Check $setupfile."
	[[ ! -d "$BB_BUILD" ]] && fatal "Invalid bitbake build dir. Check $setupfile."

	targets="$@"
	[[ -z "$targets" ]] && targets=${BUILD[targets]}
	[[ -z "$targets" ]] && fatal "No targets specified"

	info "Starting build"
	info "   FLAVOUR:     $FLAVOUR"
	info "   MACHINE:     $MACHINE"
	info "   BB_BUILD:    $BB_BUILD"
	info "   BB_TARGETS:  $targets"

	. $BB_BUILD/agl-init-build-env || fatal "Unable to source bitbake environment"

	local ts0=$(date +%s)
	local status=fail

 	bitbake $targets && status=ok
	
	local ts=$(( $(date +%s) - ts))
	cat <<EOF >>$(get_setupfile)
# ---------- build at $(date -u -Iseconds -d @$ts0) -------
# deploy dir as generated by 'bitbake $targets'
BB_TARGETS="$targets"
BB_DEPLOY=${BB_BUILD}/tmp/deploy
BB_TS="$ts0"
BB_BUILDTIME="$(date +%H:%M:%S -u -d @$ts)"
BB_STATUS=$status
EOF

	[[ $status == "ok" ]] && {
		info "Bitbake build succeeded for ($FLAVOUR:$MACHINE:$targets)"
	} || {
		fatal "Build failed ($FLAVOUR:$MACHINE:$targets)"
	}
}

function command_deploy() {
	local EXCLUDE_PATTERN="*ostree* *otaimg *.tar.xz"
	local doimage=y dopackages=n dosdk=y

	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options]
   options:
      -h|--help    : get this help
	  -i|--image   : enable image deployment (default: yes)
	  --no-image   : disable image deployment
	  -p|--packages: enable packages deployment (default: no)
	  -s|--sdk     : enable SDK deployment (default: yes)
	  --no-sdk     : disable SDK deployment
      -x|--exclude : file exlusion pattern when copying
                     default: $EXCLUDE_PATTERN
EOF
	}

	local opts="-o h,i,p,s,x: --long,--image,--no-image,--packages,--sdk,--no-sdk,--exclude: help" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; _usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-h|--help) __usage; return 0;;
			-i|--image) doimage=y; shift;;
			--no-image) doimage=n; shift;;
			-p|--packages) dopackages=y; shift;;
			-s|--sdk) dosdk=y; shift;;
			--no-sdk) dosdk=n; shift;;
			-x|--exclude) EXCLUDE_PATTERN=$2; shift 2;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	setupfile=$(get_setupfile)
	[[ ! -f $setupfile ]] && fatal "Setup file $setupfile not found. Does '$MYNAME prepare' has been run ?"

	. $setupfile

	[[ "$BB_STATUS" != "ok" ]] && fatal "Last build failed. Check $setupfile."
	[[ ! -d "$BB_DEPLOY" ]] && fatal "Invalid bitbake deploy dir. Check $setupfile."

	# locate image and version
	local imgfile imgdir
	[[ "$doimage" == "y" ]] && {
		imgdir="$BB_DEPLOY/images/${MACHINE}/"
		[[ ! -d "$imgdir" ]] && fatal "No image dir found at $imgdir" 
		pushd $imgdir &>/dev/null
			local lnkname=$(find . -type l -name "*.wic.xz")
			[[ -z "$lnkname" ]] && lnkname=$(find . -type l -name "*.wic.vmdk") # exception for qemu
			[[ ! -e $lnkname ]] && fatal "No image link found in $imgdir" || log "Found image link $lnkname"
			imgfile=$(readlink $lnkname)
			[[ ! -f $imgfile ]] && fatal "No image found in $imgdir" || log "Found image file $imgfile"
		popd &>/dev/null
	}

	# locate SDK
	local sdkfile sdkdir
	[[ "$dosdk" == "y" ]] && {
		sdkdir="$BB_DEPLOY/sdk/"
		[[ ! -d $sdkdir ]] && fatal "No SDK dir found at $sdkdir"
		pushd $sdkdir &>/dev/null
			sdkfile=$(find . -type f -name "poky-*.sh")
			[[ ! -f $sdkfile ]] && fatal "Unable to find SDK file in $sdkdir"
		popd &>/dev/null
	}

	# locate packages
	local pkgdir
	[[ "dopackages" == "y" ]] && {
		pkgdir="$BB_DEPLOY/rpm"
		[[ ! -d $pkgdir ]] && fatal "No packages dir found at $pkgdir"
	}
	 
fatal "NOT FINISHED" # TODO
	# compute destination dir
	local DSTDIR=
[[ ! -d "${DSTDIR}" ]] && fatal "Invalid destination directory $DSTDIR"
DSTDIR=$(realpath ${DSTDIR})

# determine version
[[ "$imgfile" =~ -([0-9]+)\.rootfs\.wic\..+$ ]] && VERSION=${BASH_REMATCH[1]} || error "Unable to find image version"
log "Found version $VERSION"

# create destination dir
SAVEDIR="${DSTDIR}/${MACHINE}-${VERSION}/"
mkdir -p ${SAVEDIR}

RSYNCEXCLUDE=""
log "Exclusion pattern: ${EXCLUDE}"
for e in ${EXCLUDE}; do
	RSYNCEXCLUDE="${RSYNCEXCLUDE} --exclude "$e" "
done

BASESAVEDIR=$(basename "${SAVEDIR}")
DIRSAVEDIR=$(dirname "${SAVEDIR}")

info "Syncing $IMGDIR to $SAVEDIR..."
rsync -a --delete ${RSYNCEXCLUDE} ${IMGDIR}/ ${SAVEDIR}/
[[ -n "$sdkfile" ]] && { log "Syncing SDK file $sdkfile to $SAVEDIR"; rsync -a ${SDKDIR}/$sdkfile ${SAVEDIR}/; }

if [[ -L ${DIRSAVEDIR}/${MACHINE} ]]; then
	rm ${DIRSAVEDIR}/${MACHINE}
fi
if [[ ! -e ${DIRSAVEDIR}/${MACHINE} ]]; then
	ln -sf ${BASESAVEDIR} ${DIRSAVEDIR}/${MACHINE}
fi

log "Image saved in $SAVEDIR"
	# TODO
}
