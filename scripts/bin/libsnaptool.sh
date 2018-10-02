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
		cat <<EOF >$CONFIG_FILE
# configuration file for snaptool
# see https://github.com/iotbzh/agl-manifest/tree/master/scripts for more information

# how mirror can be mounted/unmounted and accessed locally
MIRROR[path]=$HOME/mirror
MIRROR[mount]=
MIRROR[umount]=

RESOURCES[path]=$HOME/mirror/proprietary-renesas-r-car
RESOURCES[mount]=
RESOURCES[umount]=

# temp build folder
BUILD[path]=$XDT_DIR
BUILD[mount]=
BUILD[umount]=

# deployment folder
DEPLOY[path]=$XDT_DIR/deploy
DEPLOY[mount]=
DEPLOY[umount]=
EOF
	}
	[[ ! -f $CONFIG_FILE ]] && fatal "Unable to find config file $CONFIG_FILE"

	# load configuration file
	info "Loading config file $CONFIG_FILE"
	. $CONFIG_FILE
}

__configure

# ------------------------ ops on folders -----------------------------------------

function folders_check() {
	for x in $FOLDERS; do
		typeset -n folder=$x
		[[ ! -d ${folderx[path]} ]] && { error "Directory '${folder[path]}' ($x) doesn't exist"; return 1; }
		debug "Directory ${x[path]} is available"
	done
	return 0
}

function folders_mount() {
	for x in $FOLDERS; do
		typeset -n folder=$x
		[[ -n "${folder[mount]}" ]] && echo "Running mount command for $x: ${folder[mount]}"
	done
}

function folders_umount() {
	for x in $FOLDERS; do
		typeset -n folder=$x
		[[ -n "${folder[umount]}" ]] && echo "Running umount command for $x: ${folder[umount]}"
	done
}

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
# ------------------------- top level commands ----------------------------------

function command_gcdebug() {
	debug "Retention dates:"
	for x in $(compute_dates "$@"); do
		debug $x $(date --utc "+%a" -d $x)
	done
	#simulate
	#get_snapshots_age "$@"
}

function command_mount() {
	local dryrun=

	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options] 
   options:
      -n|--dryrun : do nothing
      -h|--help   : get this help
EOF
	}

	local opts="-o n,h --long dryrun,help" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; _usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-n|--dryrun) dryrun=1; shift;;
			-h|--help) __usage; exit 1;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	# TODO
	debug "$COMMAND dryrun=$dryrun args=$@"
}

function command_umount() {
	local dryrun=

	function __usage() {
		cat <<EOF >&2
Usage: $COMMAND [options] 
   options:
      -n|--dryrun : do nothing
      -h|--help   : get this help
EOF
	}

	local opts="-o n,h --long dryrun,help" tmp
	tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>/dev/null) || {
		tmp=$(getopt $opts -n "$COMMAND" -- "$@" 2>&1 >/dev/null) || true
		error $tmp; _usage; return 1
	}
	eval set -- $tmp

	while true; do	
		case "$1" in 
			-n|--dryrun) dryrun=1; shift;;
			-h|--help) __usage; exit 1;;
			--) shift; break;;
			*) fatal "Internal error";;
		esac
	done

	# TODO
	debug "$COMMAND dryrun=$dryrun args=$@"
}

# ----------------------------------------------------------------------

