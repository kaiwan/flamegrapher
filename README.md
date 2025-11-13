# Quick Summary

This is a swapper over Brendan Gregg's [original](https://github.com/brendangregg/FlameGraph) - and wonderful! - FlameGraph software. It's USP - it makes it even easier to use, both in the default case as well as with helpful options tacked on.

A sample FlameGraph - generated while `rm -rf <filespec>` was running:
![sample FlameGraph - generated while rm -rf <filespec> was running](https://github.com/kaiwan/flamegrapher/blob/main/fg_samples/rm-rf_running1.svg)


# Details

CPU FlameGraphs are a visualization of profiled software, allowing the most
frequent code-paths to be identified quickly and accurately. They can be
generated using Brendan Gregg's open source programs on
github.com/brendangregg/FlameGraph

For the developer's/DevOps/whomever's convenience, we provide a wrapper to generate CPU FlameGraphs.
Run the `flame_grapher.sh` script, follow instructions.

The result:

  * A rendered SVG file - the FlameGraph! Can view it in a web browser
  * A SpeedScope file - can visualize the FlameGraph via the super [speedscope web app](https://www.speedscope.app/)


## flamegrapher `Help` screen

`Usage: flame_grapher.sh -o SVG-out-filename(without .svg) [options ...]
  -o svg-out-filename(without .svg) : MANDATORY; the name of the SVG file to generate (saved under /tmp/flamegraphs/<SVG-out-filename>)`

Generate a CPU Flame Graph

Options:

` -h|-?`           Show this help screen and exit

`-c "command"`    Generate a Flame Graph for ONLY this command-line (it's process's/threads)
                 You MUST specify multi-word commands within quotes; f.e. `"ls -laR"` (see Examples below)
                 NOTE: If a program named `foo` with a parameter named `param1` in the current dir is to be executed, don't give `-c "./foo param1"`, instead give it as `-c "$(pwd)/foo param1"`

 -p PID          Generate a Flame Graph for ONLY this process or thread
                 
&nbsp; **NOTE**: If neither -c nor -p is passed, the *entire system* is sampled... Furthermore:
               
&nbsp; `-c "cmd"` and `-p PID` are mutually exclusive options; you can specify only one of them.

` -s <style>` : `normal` :  Draw the stack frames growing upward   \[default]

              `icicle` :  Draw the stack frames growing downward

` -t <type>`  : `graph` :     Produce a Flame Graph (X axis is NOT time, merges stacks) [default]
                          -good for performance outliers (who's eating CPU? using max stack?);
Works well for multi-threaded apps

              `chart` :    Produce a Flame Chart (sort by time, do not merge stacks)
                          -good for seeing all calls; works well for single-threaded apps
 -f <freq>  :            Have perf sample the system/process at [default=99]
                          -too high a value here can cause issues.

**NOTE:**

* After pressing ^C to stop, please be patient... it can take a while to process.
* The FlameGraph SVG (and perf.data file) are stored in the volatile /tmp/flamegraphs/<SVG-out-filename> dir;
  copy them to a non-volatile location to save them
* As a bonus, this script also generates a **'speedscope'** input file, a flamegraph viewable
  in the [speedscope web app](https://www.speedscope.app/)
  
TIP: Within it's web page, the top line shows available lookup (and other) options:

`   Time Order   Left Heavy   Sandwich           <process-name> tid: <TID> (thrd#/total#)    Export  Import  <Style>  Help`

  Use these to lookup all/particular threads, export it (json), etc
  [Speedscope help available here](https://github.com/jlfwong/speedscope#usage).


## Example Usage

* `flame_grapher.sh -o whole_system`
    \# Sample the *entire system* and generate the FG (in /tmp/flamegraphs/whole_system/whole_system.svg)
* `flame_grapher.sh -o ls-laR-usr -c "ls -laR /usr"`
 \# Run the cmd "ls -laR /usr" and generate the FG (in /tmp/flamegraphs/la-laR-usr/ls-laR-usr.svg)
* `flame_grapher.sh -o ps-efwww -c "ps -efwww" -t chart`
 \# Run the cmd "ps -efwww" and generate a Flame *Chart* (in /tmp/flamegraphs/ps-efwww/ps-efwww.svg)
* `PID=$(pgrep --oldest git); flame_grapher.sh -p ${PID} -s icicle -f200 -o git_whatrudoing`
<br>\# Sample the 'git' process (at 200 Hz), generate the 'icicle' style FG (in /tmp/flamegraphs/git_whatrudoing/git_whatrudoing.svg)


(Of course, when running the script from it's git directory - when it isn't in your `PATH` - pl use the 'dot-slash prefix): `./flame_grapher.sh -o ...`


## IMPORTANT: Getting a decent FlameGraph works best when:

* Symbols are present in the binary executable (i.e., when the binary isn't stripped of all symbols)
* Frame Pointers are enabled (-fomit-frame-pointer is the typical GCC flag!
    Use the -fno-omit-frame-pointer in your build; it doesn't guarantee FP's
    are used though..)
* The Linux kernel symbols are present when the kernel config `CONFIG_DEBUG_KERNEL` is set (to `y`).


## Known Issues

I came across this issue with the (original) flamegraph Perl script on an AArch64
Yocto-based custom embedded Linux..:

...
`Can't locate open.pm in @INC (you may need to install the open module) (@INC entries checked: /usr/lib/perl5/site_perl/5.38.2/aarch64-linux /usr/lib/perl5/site_perl/5.38.2 ...`

Brendan Gregg comments upon this very issue here:
https://github.com/brendangregg/FlameGraph/issues/245

The QUICK workaround:
simply comment out this line in the original flamegraph.pl Perl script file:

`use open qw(:std :utf8);`

The dependency then disappears & it still works (albeit without UTF8)..
