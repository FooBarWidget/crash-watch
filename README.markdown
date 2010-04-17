# Introduction

* Do you have (server) processes that sometimes crash for mysterious reasons?
* Can you not figure out why?
* Do they not print any error messages to their log files upon crashing?
* Are debuggers complicated, scary things that you'd rather avoid?

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
    Exit code: 0
    Backtrace:
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

While monitoring the process, you may interrupt `crash-watch` by pressing Ctrl-C. `crash-watch` will then detach from the process, which will then continue normally. You may re-attach `crash-watch` later.

## Goodie: GDB controller

I've written a small library for controlling gdb, which `crash-watch` uses internally. With CrashWatch::GdbController you can send arbitrary commands to gdb and also get its response.

Instantiate with:

    require 'crash_watch/gdb_controller'
    gdb = CrashWatch::GdbController.new

This will spawn a new GDB process. Use `#execute` to execute arbitary GDB commands. Whatever the command prints to stdout and stderr will be available in the result string.

    gdb.execute("bt")        # => backtrace string
    gdb.execute("p 1 + 2")   # => "$1 = 3\n"

Call `#close` when you no longer need it.

    gdb.close
