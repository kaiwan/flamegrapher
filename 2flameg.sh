#!/bin/bash
# 2flameg.sh
# INVOKED from flame_grapher.sh via trap to INTerrupt ^C or EXIT !
# Generate a CPU FlameGraph !
#
# CPU FlameGraph wrapper script.
# Simple wrapper over Brendan Gregg's superb FlameGraphs!
# Part 2 of 2.
#
# CREDITS: Brendan Gregg, for the original & simply superb FlameGraph
#
# Kaiwan N Billimoria, kaiwanTECH
# License: MIT

# 5 params passed:
# $1 : result folder
# $2 : SVG filename
# $3 : style to draw graph in
#        0 => regular
#        1 => icicle (downward-growing!)
# $4 : type of FG
#        0 => regular Flame *Graph* ; merged stack; X-axis is alphabetical (good for MT, shows outliers)
#        1 => Flame *Chart* ; all stacks; X-axis is timeline (ok for single-threaded)
# $5 : cmdline str passed, if any (if -c option's used this is non-NULL)
name=$(basename $0)
source colors.sh
#echo "$0: #p = $# ; parms: $*"
# f.e. output is:
# #p = 5 ; parms: /tmp/flamegraphs/psla2 psla2.svg 0 0 ps -LA
# 5 params!               $1                $2     $ $   $5
#                                                  3 4

# Can examine the callstacks (flamegraph/flamechart?) in speedscope
# https://www.speedscope.app/
speedscope_gen()
{
cd ${RES_DIR} || exit 1
local SPEEDSCOPE_FILE="speedscope_${OUTFILE::-4}.txt"
#echo "sudo perf script --input ${INFILE} > ${SPEEDSCOPE_FILE}"
red_fg "
--- speedscope ---"
sudo perf script --input ${INFILE} -f > ${SPEEDSCOPE_FILE}
sudo chown ${LOGNAME}:${LOGNAME} ${SPEEDSCOPE_FILE}
ls -lh $(realpath ${SPEEDSCOPE_FILE})
echo "- ${SPEEDSCOPE_HELP}"
red_fg "---"
}


# Find whether run from the command-line !
# ref: https://stackoverflow.com/a/4262107/779269
tok=$(ps -o stat= -p $PPID)  # yields 'S+' via script and 'Ss' via cmdline
#echo "${tok}"
[ "${tok:1:1}" = "s" ] && {
 echo "${name}: This script should ONLY be invoked by the flame_grapher.sh script, not directly!"
 exit 1
}
[ $# -lt 4 ] && {
 echo "Usage: ${name} result-folder SVG-filename style-to-display(1 for icicle) type(1 for FlameChart) [cmdline]"
 exit 1
}

INFILE=perf.data
OUTFILE=${2}

TOPDIR=${PWD}
cd ${1} || exit 1
#pwd

INFILE=perf.data
RES_DIR="${1}"
OUTFILE="${2}"
STYLE=${3}
TYPE=${4}
CMD="${5}"

[ ! -f ${INFILE} ] && {
  echo "${name} : perf data file ${INFILE} invalid? Aborting..."
  cd ${TOPDIR}
  exit 1
}
if [ $3 -ne 0 -a $3 -ne 1 ] ; then
	echo "${name}: third parameter graph-style must be 0 or 1"
	exit 1
fi

echo
echo "${name}: Working ... generating SVG file \"${1}/${OUTFILE}\"..."

#---
# Interesting options to flamegraph.pl:
# (ref: https://github.com/brendangregg/FlameGraph )
# --title TEXT     # change title text
# --subtitle TEXT  # second level title (optional)
# --inverted       # icicle graph ; downward-growing
# --flamechart     # produce a flame chart (sort by time, do not merge stacks)
# --width NUM      # width of image (default 1200)
# --hash           # colors are keyed by function name hash
# --cp             # use consistent palette (palette.map)
# --notes TEXT     # add notes comment in SVG (for debugging)
WIDTH=1900  # can make it v large; you'll just have to scroll horizontally...
TITLE="CPU mixed-mode Flame"
# ${name} result-folder SVG-filename style-to-display(1 for icicle) type(1 for FlameChart)" [cmdline]
#            p1               p2           p3:STYLE                      p4:TYPE            p5:cmdline

#echo "******************** OPTS = ${opts}"

[ ${TYPE} -eq 1 ] && PTYPE=--flamechart
NOTES="notes text: "
if [ ${STYLE} -eq 0 ] ; then   # normal upward-growing stacks [default]
   [ ${TYPE} -eq 0 ] && {
     TITLE="${TITLE}Graph ${OUTFILE}; style is normal (upward-growing stacks), type is Graph (merged stacks)"
     NOTES="${NOTES}CPU mixed-mode Flame Graph, type normal"
   } || {
     TITLE="${TITLE}Graph ${OUTFILE}; style is normal (upward-growing stacks), type is Chart (all stacks)"
     NOTES="${NOTES}CPU mixed-mode Flame Graph, type chart"
   }
else
  [ ${TYPE} -eq 1 ] && {   # icicle: downward-growing stacks
	 TITLE="${TITLE}Chart ${OUTFILE}; style is Flame Chart (all stacks, X-axis is timeline)"
	 NOTES="${NOTES}CPU mixed-mode Flame Chart, type flamechart"
  } || {
	 TITLE="${TITLE}Graph ${OUTFILE}; style is Flame Graph (merged stacks)"
	 NOTES="${NOTES}CPU mixed-mode Flame Graph, type normal"
  }
fi

#set -x
[[ -n "${CMD}" ]] && TITLE="${TITLE}; cmdline: \"${CMD}\""

if [[ ${STYLE} -eq 0 ]] ; then
  sudo perf script --input ${INFILE} | ${FLMGR}/stackcollapse-perf.pl | \
     ${FLMGR}/flamegraph.pl --title "${TITLE}" --subtitle "${OUTFILE}" ${PTYPE} \
	  --notes "${NOTES}" --width ${WIDTH} > ${OUTFILE} || {
	echo "${name}: failed."
	exit 1
  }
elif [[ ${STYLE} -eq 1 ]] ; then  # add the --inverted option
  sudo perf script --input ${INFILE} | ${FLMGR}/stackcollapse-perf.pl | \
     ${FLMGR}/flamegraph.pl --title "${TITLE}" --subtitle "${OUTFILE}" ${PTYPE} \
	  --notes "${NOTES}" --width ${WIDTH} --inverted > ${OUTFILE} || {
	echo "${name}: failed."
	exit 1
  }
fi
# NOPE it doesn't work when i tried to place all the opts in a variable!
# [[ ${STYLE} -eq 1 ]] && FLAMEGRAPH_PERL_OPTS="${FLAMEGRAPH_PERL_OPTS} --inverted"

USERNM=$(echo ${LOGNAME})
sudo chown -R ${USERNM}:${USERNM} ${TOPDIR}/${1}/ 2>/dev/null
cd ${TOPDIR}
ls -lh ${1}/${OUTFILE}
echo

echo "<NOTES:> in the SVG (if any):"
grep -w "NOTES\:" ${1}/${OUTFILE}

# Display in chrome !
if [[ -f $(which google-chrome-stable) ]] ; then
  nohup google-chrome-stable --incognito --new-window ${1}/${OUTFILE} &
else
  echo "View the above SVG file in your web browser to see and zoom into the CPU FlameGraph."
fi

echo "*NOTE* The SVG file \"${1}/${OUTFILE}\" is in a volatile temp folder; pl save it as required"

speedscope_gen
#exit 0
