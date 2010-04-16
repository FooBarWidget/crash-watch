# Introduction

* Do you have (server) processes that sometimes crash for mysterious reasons?
* Can you not figure out why?
* Do they not print any error messages to their log files upon crashing?

`crash-watch` to the rescue! This little program will monitor a specified process and wait until it crashes. It will then print useful information such as its exit status, what signal caused it to abort, and its backtrace.

## Installation

    gem install crash-watch

You must also have GDB installed. Mac OS X already has it by default. If you're on Linux, try one of these:

    apt-get install gdb
    yum install gdb

## Sample usage

    $ crash-watch <PID>
    Monitoring PID <PID>...
    (...some time later, <PID> exits...)
    Process exited.
    Exit code = 0
    Backtrace = [
    Thread 1 (process 95205):
    #0  0x00007fff87ea1db0 in _exit ()
    No symbol table info available.
    #1  0x000000010002a260 in ruby_stop ()
    No symbol table info available.
    #2  0x0000000100031a54 in ruby_run ()
    No symbol table info available.
    #3  0x00000001000009e4 in main ()
    No symbol table info available.
    ]