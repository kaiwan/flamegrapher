#!/bin/bash
# Generate CPU FlameGraph wrapper script.
# Simple wrapper over Brendan Gregg's superb CPU FlameGraphs!
# Part 1 of 2.
# This script records the perf data file, and then invokes the
# second script 2flameg.sh which renders the SVG file.
# All "result" files are under the 'result/' folder.
#
# CREDITS: Brendan Gregg, for the original & simply superb FlameGraph
#
# Kaiwan N Billimoria, kaiwanTECH
# License: MIT

# Turn on unofficial Bash 'strict mode'! V useful
# "Convert many kinds of hidden, intermittent, or subtle bugs into immediate, glaringly obvious errors"
# ref: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

name=$(basename "$0")
PDIR=$(which "$0")
[ -z "${PDIR}" ] && PDIR=$(dirname "$0")  # true if this script isn't in PATH
export PFX=$(dirname "${PDIR}")		# dir in which this script and tools reside
export FLMGR=~/FlameGraph		# location of original BGregg's FlameGraph repo code
PERF_RESULT_DIR_BASE=/tmp/flamegraphs	# change to make it non-volatile
STYLE_INVERTED_ICICLE=0
TYPE_CHART=0
HZ=99

source colors.sh

# TODO
#  [+] add -c cmdline option
#  [ ] add -d duration param
#  [+] show current config on run
# ISSUES
#  [X] why does 2flameg.sh seem to run twice?? the 'exit' and ^C ?

export SPEEDSCOPE_HELP1="As a bonus, this script also generates a 'speedscope' input file, a flamegraph viewable
  in the speedscope web app: https://www.speedscope.app/
  TIP: Within it's web page, the top line shows available lookup (and other) options:"
export SPEEDSCOPE_HELP2="   Time Order   Left Heavy   Sandwich           <process-name> tid: <TID> (thrd#/total#)    Export  Import  <Style>  Help"
export SPEEDSCOPE_HELP3="  Use these to lookup all/particular threads, export it (json), etc
  Speedscope help available here: https://github.com/jlfwong/speedscope#usage"

usage()
{
  red_fg "Usage: ${name} -o SVG-out-filename(without .svg) [options ...]
  -o svg-out-filename(without .svg) : MANDATORY; the name of the SVG file to generate (saved under ${PERF_RESULT_DIR_BASE}/<SVG-out-filename>)

Generate a CPU Flame Graph"
  echo "
Options:
 -h|-?           Show this help screen and exit
 -c \"command\"    Generate a Flame Graph for ONLY this command-line (it's process's/threads)
                 You MUST specify multi-word commands within quotes; f.e. \"ls -laR\" (see Examples)"
  gray_fg "                 NOTE: If a program named 'foo' with a parameter named 'param1' in the current dir is to be executed, 
                       don't give -c \"./foo param1\", instead give it as: -c \"\$(pwd)/foo param1\""
  echo "
 -p PID          Generate a Flame Graph for ONLY this process or thread"
  gray_fg "                 NOTE: * If neither -c nor -p is passed, the *entire system* is sampled...
                       * -c \"cmd\" and -p PID are mutually exclusive options; you can specify only one of them."
  echo "
 -s <style> : normal     Draw the stack frames growing upward   [default]
              icicle     Draw the stack frames growing downward
 -t <type>  : graph      Produce a Flame Graph (X axis is NOT time, merges stacks) [default]
                          -good for performance outliers (who's eating CPU? using max stack?);
			  -works well for multi-threaded apps
              chart      Produce a Flame Chart (sort by time, do not merge stacks)
                          -good for seeing all calls; works well for single-threaded apps
 -f <freq>  :            Have perf sample the system/process at [default=${HZ}]
                          -too high a value here can cause issues."
  green_fg "
NOTE:
o After pressing ^C to stop, please be patient... it can take a while to process.
o The FlameGraph SVG (and perf.data file) are stored in the volatile ${PERF_RESULT_DIR_BASE}/<SVG-out-filename> dir;
  copy them to a non-volatile location to save them
o ${SPEEDSCOPE_HELP1}"
blue_fg "${SPEEDSCOPE_HELP2}"
green_fg "${SPEEDSCOPE_HELP3}"

  red_fg "
Examples:"
  echo " o ${name} -o whole_system                        # Sample the *entire system* and generate the FG (in ${PERF_RESULT_DIR_BASE}/whole_system/whole_system.svg)
 o ${name} -o ls-laR-usr -c \"ls -laR /usr\"        # Run the cmd \"ls -laR /usr\" and generate the FG (in ${PERF_RESULT_DIR_BASE}/la-laR-usr/ls-laR-usr.svg)
 o ${name} -o ps-efwww -c \"ps -efwww\" -t chart    # Run the cmd \"ps -efwww\" and generate a Flame *Chart* (in ${PERF_RESULT_DIR_BASE}/ps-efwww/ps-efwww.svg)
 o PID=\$(pgrep --oldest git); ${name} -p \${PID} -s icicle -f200 -o git_whatrudoing
    # Sample the 'git' process (at 200 Hz), generate the 'icicle' style FG (in ${PERF_RESULT_DIR_BASE}/git_whatrudoing/git_whatrudoing.svg)
"
}

function die
{
red_highlight >&2 "${name}: *FATAL*  $*"
exit 1
}

display_opts()
{
local opts=""

opts="- SVG and speedscope files will be generated here: ${PERF_RESULT_DIR_BASE}/${OUTFILE}/${OUTFILE}.svg"
[[ -n "${CMD}" ]] && opts="${opts}
- Command run: \"${CMD}\""
[[ -n "${PID}" ]] && opts="${opts}
- Process with PID ${PID} sampled"
if [[ ${STYLE_INVERTED_ICICLE} -eq 0 ]] ; then
   opts="${opts}
- Flame Graph with upward-growing stacks [default]"
elif [[ ${STYLE_INVERTED_ICICLE} -eq 1 ]] ; then
   opts="${opts}
- Flame Graph with downward-growing stacks / icicles" 
fi
if [[ ${TYPE_CHART} -eq 0 ]] ; then
   opts="${opts}
- Regular Flame Graph: merged stacks, X-axis is alphabetical, >> rectangle width shows outlier(s) [default]"
elif [[ ${TYPE_CHART} -eq 1 ]] ; then
   opts="${opts}
- Flame Chart: all stacks, X-axis is timeline"
fi

blue_fg "Current Options:
${opts}
"
}


### "main" here

# prereqs
which perf >/dev/null 2>&1 || die "${name}: perf not installed? Aborting...
 Tip- (Deb/Ubuntu) sudo apt install linux-tools-$(uname -r) linux-tools-generic"
[ ! -f ${PFX}/2flameg.sh ] && die "The part-2 script 2flameg.sh is missing? Aborting..."
[ ! -d ${FLMGR} ] && die "I find that the original FlameGraph GitHub repo isn't installed.
 You need to (one-time) install it (under your home dir).
 In your terminal window/shell, type (including the parentheses) -OR- simply copy-paste the line below:
 (cd; git clone https://github.com/brendangregg/FlameGraph)"

# RedHat-like distros are often missing the perl-open package, req by the FlameGraph perl script
lsb_release -i|egrep -i "RedHat|Alma|Rocky" && {
  yum list installed|grep perl-open >/dev/null || sudo yum install perl-open.noarch
}

[ $# -lt 1 ] && {
  usage
  exit 1
}
[ "$1" = "--help" ] && {
  usage
  exit 0
}

#--- getopts processing
optspec=":o:c:p:s:t:f:h?" # a : after an arg implies it expects an argument
# To prevent shellcheck's 'unbound variable' error:
OUTFILE="" ; CMD="" ; PID=""
while getopts "${optspec}" opt
do
    #echo "opt=${opt} optarg=${OPTARG}"
    case "${opt}" in
	  o)
 	        OUTFILE=${OPTARG}
	        #echo "-o passed; outfile=${OUTFILE}"
		;;
	  c)
		CMD="${OPTARG}"
		#echo "-c passed; cmd=\"${CMD}\""
		;;
	  p)
 	        PID=${OPTARG}
	        #echo "-p passed; PID=${PID}"
		# Check if PID is valid
		sudo kill -0 ${PID} 2>/dev/null || die "PID ${PID} is an invalid (or dead) process/thread?"
		;;
	  s)
	        STYLE=${OPTARG}
	        #echo "-s passed; STYLE=${STYLE}"
		if [ "${STYLE}" != "normal" ] && [ "${STYLE}" != "icicle" ]; then
			usage ; exit 1
		fi
		[ "${STYLE}" = "icicle" ] && STYLE_INVERTED_ICICLE=1
		;;
	  t)
 	        TYPE=${OPTARG}
	        #echo "-f passed; TYPE=${TYPE}"
		if [ "${TYPE}" != "graph" ] && [ "${TYPE}" != "chart" ]; then
			usage ; exit 1
		fi
		[ "${TYPE}" = "chart" ] && TYPE_CHART=1
		;;
	  f)
 	        HZ=${OPTARG}
	        #echo "-f passed; HZ=${HZ}"
		;;
	  h|?)
		usage
		exit 0
		;;
	  *)	echo "Unknown option '-${OPTARG}'" ; usage; exit 1
		;;
  	  esac
done
shift $((OPTIND-1))

[ -z "${OUTFILE}" ] && {
  usage ; exit 1
} || true
[[ "${OUTFILE}" = *"."* ]] && die "Please ONLY specify the name of the SVG file; do NOT put any extension (give xyz not xyz.svg)"
[[ -n ${PID} ]] && [[ -n ${CMD} ]] && die "Specify EITHER the command-to-run (-c) OR the process PID (-p), not both"
SVG=${OUTFILE}.svg
PDIR=${PERF_RESULT_DIR_BASE}/${OUTFILE}
TOPDIR=$(pwd)
#red_fg "pwd = $(pwd); TOPDIR=${TOPDIR}; PFX=${PFX}"

#--- Get Ready to run the part 2 - generating the FG - on interrupt (^C) or exit !
trap 'ls -lh ${PDIR}/perf.data; cd ${TOPDIR}; sync ; ${PFX}/2flameg.sh ${PDIR} ${SVG} ${STYLE_INVERTED_ICICLE} ${TYPE_CHART} "${CMD}"' INT EXIT
#trap 'cd ${TOPDIR}; echo Aborting run... ; sync ; exit 1' QUIT
#---

mkdir -p "${PDIR}" || die "mkdir -p ${PDIR}"
sudo chown -R "${LOGNAME}":"${LOGNAME}" ${PERF_RESULT_DIR_BASE} 2>/dev/null || true
cd "${PDIR}" || echo "*Warning* cd to ${PDIR} failed"

display_opts

MSG_CMDLINE_STOP="Please DO allow the command to complete ...
If you Must stop it, press ^C ...
 *NOTE* After pressing ^C to stop it, PLEASE be patient... it can take a while to process..."
MSG_STOP="Press ^C to stop...
 *NOTE* After pressing ^C to stop, PLEASE be patient... it can take a while to process..."

if [ ! -z "${CMD}" ]; then  #------------------ Profile a particular command-line
 echo "### ${name}: recording samples on the command \"${CMD}\" now...
 ${MSG_CMDLINE_STOP}"
 sudo perf record -F "${HZ}" --call-graph dwarf ${CMD} || exit 1	# generates perf.data
elif [ ! -z "${PID}" ]; then  #------------------ Profile a particular process
 echo "### ${name}: recording samples on process PID ${PID} now...
 ${MSG_STOP}"
 sudo perf record -F "${HZ}" --call-graph dwarf -p ${PID} || exit 1	# generates perf.data
else                        #---------------- Profile system-wide
 echo "### ${name}: recording samples system-wide now...
 ${MSG_STOP}"
 sudo perf record -F "${HZ}" --call-graph dwarf -a || exit 1		# generates perf.data
fi
cd ${TOPDIR} || echo "*Warning* cd to ${TOPDIR} failed"

#exit 0  # this exit causes the 'trap' to run (as we've trapped the EXIT!)
