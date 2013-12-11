# Introduction

* Do you have (server) processes that sometimes crash for mysterious reasons?
* Can you not figure out why?
* Do they not print any error messages to their log files upon crashing?
* Are debuggers complicated, scary things that you'd rather avoid?

`crash-watch` to the rescue! This little program will monitor a specified process and wait until it crashes. It will then print useful information such as its exit status, what signal caused it to abort, and its backtrace.

## Installation with RubyGems

Run:

    gem install crash-watch

You must also have GDB installed. Mac OS X already has it by default. If you're on Linux, try one of these:

    apt-get install gdb
    yum install gdb

This gem is signed using PGP with the [Phusion Software Signing key](http://www.phusion.nl/about/gpg). That key in turn is signed by [the rubygems-openpgp Certificate Authority](http://www.rubygems-openpgp-ca.org/).

You can verify the authenticity of the gem by following [The Complete Guide to Verifying Gems with rubygems-openpgp](http://www.rubygems-openpgp-ca.org/blog/the-complete-guide-to-verifying-gems-with-rubygems-openpgp.html).

## Installation on Ubuntu

Use our [PPA](https://launchpad.net/~phusion.nl/+archive/misc):

    sudo add-apt-repository ppa:phusion.nl/misc
    sudo apt-get update
    sudo apt-get install crash-watch

## Installation on Debian

Our Ubuntu Lucid packages are compatible with Debian 6.

    sudo sh -c 'echo deb http://ppa.launchpad.net/phusion.nl/misc/ubuntu lucid main > /etc/apt/sources.list.d/phusion-misc.list'
    sudo sh -c 'echo deb-src http://ppa.launchpad.net/phusion.nl/misc/ubuntu lucid main >> /etc/apt/sources.list.d/phusion-misc.list'
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 2AC745A50A212A8C
    sudo apt-get update
    sudo apt-get install crash-watch

## Installation on RHEL, CentOS and Amazon Linux

Enable our YUM repository:

    # RHEL 6, CentOS 6
    curl -L https://oss-binaries.phusionpassenger.com/yumgems/phusion-misc/el.repo | \
      sudo tee /etc/yum.repos.d/phusion-misc.repo
    
    # Amazon Linux
    curl -L https://oss-binaries.phusionpassenger.com/yumgems/phusion-misc/amazon.repo | \
      sudo tee /etc/yum.repos.d/phusion-misc.repo

Then:

    sudo rpm --import https://oss-binaries.phusionpassenger.com/yumgems/phusion-misc/RPM-GPG-KEY.asc
    sudo yum install rubygem-crash-watch

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

While monitoring the process, you may interrupt `crash-watch` by pressing Ctrl-C. `crash-watch` will then detach from the process, which will then continue normally. You may re-attach `crash-watch` later.

Consult `crash-watch --help` for more usage options.

## Dumping live backtrace

Instead of waiting until a process crashes, you can also dump a live backtrace of a process. `crash-watch` will immediately exit after dumping the backtrace, letting the process continue as normally.

    $ crash-watch --dump <PID>
    Current thread (1) backtrace:
        #0  0x00007fff81fd9464 in read ()
        No symbol table info available.
        #1  0x0000000100060d3e in ?? ()
        No symbol table info available.

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
