CPU FlameGraphs are a visualization of profiled software, allowing the most
frequent code-paths to be identified quickly and accurately. They can be
generated using Brendan Gregg's open source programs on
github.com/brendangregg/FlameGraph

For the developer's convenience, we provide a wrapper to generate CPU FlameGraphs.
Run the flame_grapher.sh script, follow instructions.
The result is a rendered SVG file - the FlameGraph!
You can view it in a web browser.

The *style* of the flamegraph can be one of:
- regular: 'upward-growing' [the default], or
- icicle : 'downward-growing'
You can change it by editing the script:
flame_grapher.sh:STYLE_INVERTED_ICICLE=0  to the value 1.

**IMP NOTE**

Getting a decent FlameGraph REQUIRES:
- Frame Pointers (-fomit-frame-pointer is the typical GCC flag!
    Use the -fno-omit-frame-pointer in your build; it doesn't guarantee FP's
    are used though..
  - Possible exception case is the Linux kernel itself; it has intelligent
    algorithms to emit an accurate stack trace even in the absence of frame pointers
  - Symbols (can use a separate symbol file)


**Known Issues**

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


**Example sessions**

`
     $ ./flame_grapher.sh   
Usage: flame_grapher.sh -o svg-out-filename(without .svg) [options ...]

  -o svg-out-filename(without .svg) : name of SVG file to generate (saved under /tmp/flamegraphs/)

Optional switches:

 [-p PID]     : PID = generate a FlameGraph for ONLY this process or thread
                 If not passed, the *entire system* is sampled...

 [-s <style\>] : normal = draw the stack frames growing upward   \[default\]
                icicle = draw the stack frames growing downward

 [-t <type\>]  : graph  = produce a flame graph (X axis is NOT time, merges stacks) [default]
                   Good for performance outliers (who's eating CPU? using max stack?); works well for multi-threaded apps

                chart  = produce a flame chart (sort by time, do not merge stacks)
                         Good for seeing all calls; works well for single-threaded apps

 [-f <freq\>]  : frequency (HZ) to have perf sample the system/process at [default=99]
                      Too high a value here can cause issues

 -h|-?        : show this help screen.

Note that the FlameGraph SVG (and perf.data file) are stored in the volatile /tmp/flamegraphs dir;
copy them to a non-volatile location to save them.
$ ` 


1. Capturing a FlameGraph of a system-wide trace
------------------------------------------------
`$ ./flame_grapher.sh sys1
### flame_grapher.sh: recording samples system-wide now...Press ^C to stop...
^C[ perf record: Woken up 120 times to write data ]
[ perf record: Captured and wrote 50.111 MB perf.data (6537 samples) ]

2flameg.sh: Working ... generating SVG file "/tmp/flamegraphs/sys1/sys1.svg"...
addr2line: DWARF error: section .debug_info is larger than its filesize! (0x93ef57 vs 0x530ea0)

[...]
-rw-rw-r-- 1 kaiwan kaiwan 2.3M Jun 23 18:09 /tmp/flamegraphs/sys1/sys1.svg

View the above SVG file in your web browser to see and zoom into the CPU FlameGraph.
$` 


2. Capturing a FlameGraph of a particular process trace (VirtualBox)
--------------------------------------------------------------------
`$ ./flame_grapher.sh -p 991798 -o vbox1
### flame_grapher.sh: recording samples on process PID 991798 now... Press ^C to stop...
^C[ perf record: Woken up 14 times to write data ]
[ perf record: Captured and wrote 5.476 MB perf.data (644 samples) ]

2flameg.sh: Working ... generating SVG file "/tmp/flamegraphs/vbox1/vbox1.svg"...
addr2line: DWARF error: section .debug_info is larger than its filesize! (0x93ef57 vs 0x530ea0)
[...]
-rw-rw-r-- 1 kaiwan kaiwan 264K Jun 23 18:18 /tmp/flamegraphs/vbox1/vbox1.svg

View the above SVG file in your web browser to see and zoom into the CPU FlameGraph.
$` 
