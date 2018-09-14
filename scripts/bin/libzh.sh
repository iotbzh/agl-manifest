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

stdout_in_terminal=0
[[ -t 1 ]] && stdout_in_terminal=1
function color {
	[[ $stdout_in_terminal == 0 ]] && return
	for k in $*; do
		case $k in
			bold) tput bold 2>/dev/null;;
			none) tput sgr0 2>/dev/null;;
			*) tput setaf $k 2>/dev/null;;
		esac
	done
}

color_green=$(color bold 2)
color_yellow=$(color bold 3)
color_red=$(color bold 1)
color_blue=$(color bold 4)
color_gray=$(color 250)
color_none=$(color none)

function dumpcolors() {
	printcol(){
		for c; do
			printf '\e[48;5;%dm %03d ' $c $c
		done
		printf '\e[0m \n'
	}

	printcol {0..15}
	for ((i=0;i<12;i++)); do
		printcol $(seq $((i*18+16)) $((i*18+33)))
	done
	printcol {232..255}
}

function error() {
	echo "${color_red}$@${color_none}" >&2
}

function fatal() {
	error "$@"
	exit 56 # why 56 ? Morbihan of course!
}

function warning() {
	echo "${color_yellow}$@${color_none}" >&2
}

function info() {
	echo "${color_green}$@${color_none}" >&2
}

function debug() {
	echo "${color_gray}$@${color_none}" >&2
}


function log() {
	echo "$@" >&2
}

# template for options parsing:
#
# tmp=$(getopt -o a:hv --long arg:,help,verbose -n $(basename $BASH_SOURCE) -- "$@")
# [[ $? != 0 ]] && { usage; exit 1; }
# eval set -- $tmp
# while true; do
# 	case "$1" in 
#		-a|--arg)
#			ARG="$2";
#			shift 2;;
#		-v|--verbose)
#			VERBOSE=1;
#			shift;
#			break;;
#		-h|--help)
#			HELP=1;
#			shift;
#			break;;
#		--) shift; break;;
#		*) fatal "Internal error";;
#	esac
# done

source /etc/xdtrc 2>/dev/null || fatal "$(basename $BASH_SOURCE): Unable to source /etc/xdtrc"


