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

declare -A MIRROR RESOURCES BUILD PUBLISH
FOLDERS="MIRROR RESOURCES BUILD PUBLISH"

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
MIRROR[mount_init]="[[ ! -f ~/.ssh/id_rsa ]] && ssh-keygen -N '' -f ~/.ssh/id_rsa; ssh-copy-id sdx@thor"
MIRROR[mount]="sshfs sdx@thor:/data/snaptool_refmirror -o nonempty ${MIRROR[path]}"
MIRROR[umount]="fusermount -u ${MIRROR[path]}"

RESOURCES[path]=$HOME/mirror/proprietary-renesas-r-car
RESOURCES[mount]=
RESOURCES[umount]=

# temp build folder
BUILD[path]=$XDT_DIR
BUILD[mount]=
BUILD[umount]=
BUILD[targets]=agl-demo-platform-crosssdk

# publishing folder
PUBLISH[path]=$XDT_DIR/publish/snapshots
PUBLISH[mount_init]="[[ ! -f ~/.ssh/id_rsa ]] && ssh-keygen -N '' -f ~/.ssh/id_rsa; ssh-copy-id sdx@thor"
PUBLISH[mount]="sshfs sdx@thor:/data/snaptool_publish -o nonempty ${PUBLISH[path]}"
PUBLISH[umount]="fusermount -u ${PUBLISH[path]}"
EOF
	}
	[[ ! -f $CONFIG_FILE ]] && fatal "Unable to find config file $CONFIG_FILE"

	# load configuration file
	debug "Loading config file $CONFIG_FILE"
	. $CONFIG_FILE

	[[ -z "${MIRROR[path]}" ]] && fatal "Invalid value for MIRROR[path] in $CONFIG_FILE"
	[[ -z "${RESOURCES[path]}" ]] && fatal "Invalid value for RESOURCES[path] in $CONFIG_FILE"
	[[ -z "${BUILD[path]}" ]] && fatal "Invalid value for BUILD[path] in $CONFIG_FILE"
	[[ -z "${PUBLISH[path]}" ]] && fatal "Invalid value for PUBLISH[path] in $CONFIG_FILE"

	return 0
}

__configure

# ----------------------- commands handling -----------------------------------

function __getbuiltincommands() {
	# enumerate all:
	# - functions named command_xxxx
	# - scripts named snaptool-xxxx
	local builtins=$(typeset -F | awk '{print $3;}' | grep ^command_ | sort | sed 's/^command_[0-9]\+_//g')

	echo $builtins
}
function __getfilecommands() {
	local external=$(find $(dirname $BASH_SOURCE) -name "${MYNAME}-*" | xargs basename | sed "s/^${MYNAME}-//g" | sort)
	echo $external
}

function __callcommand() {
	cmd=$1
	shift
	local funcname=$(typeset -F | awk '{print $3;}' | grep "^command_[0-9]\+_$cmd")

	if [[ $(type -t $funcname) == "function" ]]; then
		COMMAND=$(basename $BASH_SOURCE .sh)-$cmd
		$funcname "$@"
		return $?
	fi

	# find file
	local extname=$(dirname $BASH_SOURCE)/${MYNAME}-$cmd
	if [[ -f $extname ]]; then
		$extname "$@"
		return $?
	fi

	error "Command $cmd not found"

	return 1
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
			log "Running mount command for $x: ${folder[mount]}"
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
			log "Running umount command for $x: ${folder[umount]}"
			eval ${folder[umount]} || error "Unmount failed"
		} || debug "Nothing to do for $x"
	done
	debug "folders_umount done"
}

function get_setupfile() {
	echo ${BUILD[path]}/snaptool-setup.conf
}

# --------------------------- retention policy in PUBLISH dir -------------------

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

################ FIXME - OLD CODE

#function commandBAD_gcdebug() {
#	debug "Retention dates:"
#	for x in $(compute_retention_dates "$@"); do
#		debug $x $(date --utc "+%a" -d $x)
#	done
#	#simulate
#	#get_snapshots_age "$@"
#}


# ----------------------------------------------------------------------

function command_90_mount() {
	local init

	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options] 
    options:
        -i|--init : run mount_init steps prior to mount
        -h|--help : get this help
EOF
	}

	local opts="-o i,h --long init,help" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; __usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-i|--init) init=1; shift;;
			-h|--help) __usage; return 0;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	[[ "$init" == 1 ]] && folders_init
	folders_mount
}

function command_91_umount() {
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
		error $tmp; __usage; return 1
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
}

function command_89_clean() {
	local force=0

	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options] 
   options:
      -h|--help   : get this help
      -f|--force  : remove everything including build dir
EOF
	}

	local opts="-o hf --long help,force" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; __usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-h|--help) __usage; return 0;;
			-f|--force) force=1; shift ;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	folders_umount

	setupfile=$(get_setupfile)
	if [[ -f $setupfile ]]; then
		# a build may have been done
		. $setupfile

		# clean the build dir if --force is used
		if [[ -d "$BB_TOPDIR" ]]; then 
			[[ "$force" == 1 ]] && rm -rf $BB_TOPDIR || {
				info "Leaving build dir $BUILD_DIR."
				info "Use 'snaptool clean -f' to remove it."
			}
		fi
	fi
	rm -f $setupfile
}

function command_10_prepare() {
	local init flavour machine tag="default"

	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options] -- [extra features]
    options:
        -i|--init           : run initialization steps
        -f|--flavour <name> : flavour to build
        -m|--machine <name> : machine to build for
        -t|--tag <value>    : unique tag to represent features set
                              example: when building with features "agl-demo agl-devel",
                              the tag could be 'demo-devel'
                              default tag is 'default'
        -h|--help           : get this help
   [extra features] are passed to prepare_meta
EOF
	}

	local opts="-o i,f:,m:,t:,h --long init,flavour:,machine:,tag:help" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; __usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-i|--init) init=1; shift;;
			-f|--flavour) flavour=$2; shift 2;;
			-m|--machine) machine=$2; shift 2;;
			-t|--tag) tag=$2; shift 2;;
			-h|--help) __usage; return 0;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	[[ -z "$flavour" ]] && fatal "flavour not specified"
	[[ -z "$machine" ]] && fatal "machine not specified"
	[[ -z "$tag" ]] && fatal "tag not specified"
	info "Prepare for $machine flavour $flavour tagged $tag"

	# first, do some cleanup
	__callcommand clean

	[[ "$init" == 1 ]] && folders_init
	folders_mount
	trap "folders_umount" STOP INT QUIT EXIT

	# run prepare_meta
	# NB; machine is added to output dir by prepare_meta
	local outdir=${BUILD[path]}/$flavour/$tag 
	mkdir -p $outdir || fatal "Unable to create dir $outdir"
	local mirdir=${MIRROR[path]}/$flavour/$machine/$tag

	local opts="-t $machine -f $flavour -o $outdir -l $mirdir -e wipeconfig -e cleartemp -e rm_work -p ${RESOURCES[path]}"
	local ts0=$(date +%s)
	log "Running: prepare_meta $opts"

	prepare_meta $opts "$@"

	# generate config file to be sourced by other steps (build; publish ...)
	local ts=$(( $(date +%s) - ts0))
	cat <<EOF >$(get_setupfile)
# file generated by $(basename $0)
#
# ---------- prepare at $(date -u -Iseconds -d @$ts0) -------
# prepare_meta run as:
#    prepare_meta $opts "$@"
HOST="$(id -un)@$(hostname -f)"
MACHINE=$machine
FLAVOUR=$flavour
TAG=$tag
PREPARE_TS="$ts0"
PREPARE_TIME="$(date +%H:%M:%S -u -d @$ts)"
MIRROR_DIR=$mirdir
BB_TOPDIR=$outdir
BB_META=$outdir/meta
BB_SSTATECACHE=$outdir/sstate-cache
BB_DOWNLOADS=$outdir/downloads
BB_BUILD=$outdir/build/$machine
EOF
}

function command_20_build() {
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
		error $tmp; __usage; return 1
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

	[[ -z "$MACHINE" ]] && fatal "Invalid machine name. Check $setupfile and 'prepare' step."
	[[ -z "$FLAVOUR" ]] && fatal "Invalid flavour name. Check $setupfile and 'prepare' step."
	[[ -z "$TAG" ]] && fatal "Invalid tag name. Check $setupfile and 'prepare' step."
	[[ ! -d "$BB_BUILD" ]] && fatal "Invalid bitbake build dir. Check $setupfile."

	targets="$@"
	[[ -z "$targets" ]] && targets=${BUILD[targets]}
	[[ -z "$targets" ]] && fatal "No targets specified"

	info "Starting build"
	log "   FLAVOUR:     $FLAVOUR"
	log "   MACHINE:     $MACHINE"
	log "   TAG:         $TAG"
	log "   BB_BUILD:    $BB_BUILD"
	log "   BB_TARGETS:  $targets"

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

	log "Elapsted time: $(date +%H:%M:%S -u -d @$ts)"
	[[ $status == "ok" ]] && {
		info "Bitbake build succeeded for ($FLAVOUR:$MACHINE:$targets)"
	} || {
		fatal "Build failed ($FLAVOUR:$MACHINE:$targets)"
	}
}

function command_30_publish() {
	local exclude_pattern="*ostree* *otaimg *.tar.xz"
	local doimage=y dopackages=n dosdk=y version= gcpolicy=smart

	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options]
   options:
      -h|--help    : get this help
      -i|--image   : enable image publishing (default: yes)
      --no-image   : disable image publishing
      -p|--packages: enable packages publishing (default: no)
      -s|--sdk     : enable SDK publishing (default: yes)
      --no-sdk     : disable SDK publishing
      -a|--all     : enable all parts (image, sdk, packages)
                     equivalent to -i -p -s
      -x|--exclude : file exlusion pattern when copying
                     default: $exclude_pattern
      -g|--gc      : specify garbage collecting (retention) policy for snapshots
	                 - 'smart' (default): apply a non-uniform temporal density
	                    keep last 15 days full, then 1 for every next 2 weeks,
                        then 1 for every next 2 months, then 1 for every next 5 quarters
						This gives roughly 24 snapshots covering 1.5 years.
	                 - 'duration:<duration>': drop snapshots older than the specified duration
					 - 'size:<size>': drop old snapshots based on publish folder size
	                 - 'none': do not apply any policy
      --no-gc      : an alias for '--gc none'
EOF
	}

	local opts="-o h,a,i,p,s,x:,g: --long all,image,no-image,packages,sdk,no-sdk,exclude:,gc:,--no-gc,help" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; __usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-h|--help) __usage; return 0;;
			-a|--all) doimage=y; dopackages=y; dosdk=y; shift;;
			-i|--image) doimage=y; shift;;
			--no-image) doimage=n; shift;;
			-p|--packages) dopackages=y; shift;;
			-s|--sdk) dosdk=y; shift;;
			--no-sdk) dosdk=n; shift;;
			-x|--exclude) exclude_pattern=$2; shift 2;;
			-g|--gc) gcpolicy=$2; shift 2;;
			--no-gc) gcpolicy=none; shift;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	setupfile=$(get_setupfile)
	[[ ! -f $setupfile ]] && fatal "Setup file $setupfile not found. Does '$MYNAME prepare' has been run ?"
	. $setupfile

	[[ -z "$MACHINE" ]] && fatal "Invalid machine name. Check $setupfile."
	[[ -z "$FLAVOUR" ]] && fatal "Invalid flavour name. Check $setupfile."
	[[ -z "$TAG" ]] && fatal "Invalid tag name. Check $setupfile."
	[[ "$BB_STATUS" != "ok" ]] && fatal "Last build failed. Check $setupfile."
	[[ ! -d "$BB_DEPLOY" ]] && fatal "Invalid bitbake deploy dir. Check $setupfile."
	[[ -z "$BB_TS" ]] && fatal "Invalid build timestamp. Check $setupfile."

	# use the build timestamp as version
	version=$(date -u "+%Y%m%d_%H%M%S" -d "@$BB_TS")
	
	# compute destination dir
	local destdir=${PUBLISH[path]}/$FLAVOUR/$MACHINE/$TAG/$version

	info "Starting publishing"
	log "   source dir:      $BB_DEPLOY"
	log "   version:         $version"
	log "   destination dir: $destdir"
	log "   image:           $doimage"
	log "   packages:        $dopackages"
	log "   sdk:             $dosdk"
	log "   exclude pattern: $exclude_pattern"
	log "   GC policy      : $gcpolicy"

	# locate image and version
	local imgfile imgdir
	[[ "$doimage" == "y" ]] && {
		imgdir="$BB_DEPLOY/images/${MACHINE}/"
		[[ ! -d "$imgdir" ]] && fatal "No image dir found at $imgdir" 
	}

	# locate SDK
	local sdkfile sdkdir
	[[ "$dosdk" == "y" ]] && {
		sdkdir="$BB_DEPLOY/sdk/"
		[[ ! -d $sdkdir ]] && fatal "No SDK dir found at $sdkdir"
	}

	# locate packages
	local pkgdir
	[[ "$dopackages" == "y" ]] && {
		pkgdir="$BB_DEPLOY/rpm"
		[[ ! -d $pkgdir ]] && fatal "No packages dir found at $pkgdir"
	}

	# mount publish folder
	folders_mount
	trap "folders_umount" STOP INT QUIT EXIT

	mkdir -p $destdir

	local rsyncopts="-a --delete --no-o --no-g --omit-link-times"
	for x in ${exclude_pattern}; do
		rsyncopts="${rsyncopts} --exclude '$e' "
	done

	[[ "$doimage" == "y" ]] && {
		info "Syncing $imgdir to $destdir/images ..."
		rsync $rsyncopts $imgdir/ $destdir/images/
	}
	[[ "$dosdk" == "y" ]] && {
		info "Syncing $sdkdir to $destdir/sdk ..."
		rsync $rsyncopts $sdkdir/ $destdir/sdk/
	}
	[[ "$dopackages" == "y" ]] && {
		info "Syncing $pkgdir to $destdir/rpm ..."
		rsync $rsyncopts $pkgdir/ $destdir/rpm/
	}

	info "Copying config file to $destdir"
	cp $setupfile $destdir/

	# apply GC policy
	FIXME() { error "NOT IMPLEMENTED"; }
	case $gcpolicy in
		smart)
			[[ -z "$dryrun" ]] && FIXME || true
			;;
		size*)
			[[ -z "$dryrun" ]] && FIXME || true
			;;
		duration*)
			[[ -z "$dryrun" ]] && FIXME || true
			;;
		none)
			[[ -z "$dryrun" ]] && FIXME || true
			;;
		*)
			error "Invalid Garbage Collecting policy. Skipping."
			;;
	esac
}

function command_40_mirrorupdate() {
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
		error $tmp; __usage; return 1
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

	[[ "$BB_STATUS" != "ok" ]] && fatal "Last build failed. Check $setupfile."
	[[ -z "$MIRROR_DIR" ]] && fatal "Invalid MIRROR_DIR folder. Check $setupfile."
	[[ ! -d "$BB_META" ]] && fatal "Invalid meta folder (BB_META). Check $setupfile."
	[[ ! -d "$BB_SSTATECACHE" ]] && fatal "Invalid sstate-cache folder (BB_SSTATECACHE). Check $setupfile."
	[[ ! -d "$BB_DOWNLOADS" ]] && fatal "Invalid downloads-cache folder (BB_DOWNLOADS). Check $setupfile."

	info "Starting mirrorupdate"

	folders_mount
	trap "folders_umount" STOP INT QUIT EXIT

	# do some cleanup in sstate-cache (remove duplicates and useless entries)
	info "Clean sstate-cache $BB_SSTATECACHE ..."

	local bbmanage=$BB_META/poky/scripts/sstate-cache-management.sh
	[[ -f $bbmanage ]] && {
		chmod +x $bbmanage
		$bbmanage \
			--cache-dir=$BB_SSTATECACHE \
			--remove-duplicated \
			--yes 

		$bbmanage \
			--cache-dir=$BB_SSTATECACHE \
			--stamps-dir=$BB_BUILD/tmp/stamps \
			--yes
	}

	# TODO: clean download cache (based on atime ?)
	# one way: https://lists.yoctoproject.org/pipermail/yocto/2015-October/026703.html

	# do sync
	mkdir -p $MIRROR_DIR || fatal "Unable to create mirror dir $mirdir"

	for dir in $BB_META $BB_DOWNLOADS $BB_SSTATECACHE; do
		info "Syncing $dir to $MIRROR_DIR/$(basename $dir)"
		rsync -a --no-o --no-g --omit-link-times --delete $dir/ $MIRROR_DIR/$(basename $dir)/
	done

	info "Folders size:"
	for dir in $BB_META $BB_DOWNLOADS $BB_SSTATECACHE; do
		log "   $(basename $dir) : $(du -hs $dir|awk '{print $1;}')"
	done

	# always remove agl-manifest from mirror to force refresh on manifest files
	rm -rf $MIRROR_DIR/$(basename $BB_META)/agl-manifest

	info "Mirrorupdate done"
}
