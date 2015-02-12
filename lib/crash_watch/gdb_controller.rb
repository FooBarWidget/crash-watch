# encoding: binary
#
# Copyright (c) 2010-2015 Phusion
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'rbconfig'

module CrashWatch
  class Error < StandardError
  end

  class GdbNotFound < Error
  end

  class GdbBroken < Error
  end

  class GdbController
    class ExitInfo
      attr_reader :exit_code, :signal, :backtrace, :snapshot
      
      def initialize(exit_code, signal, backtrace, snapshot)
        @exit_code = exit_code
        @signal = signal
        @backtrace = backtrace
        @snapshot = snapshot
      end
      
      def signaled?
        !!@signal
      end
    end
    
    END_OF_RESPONSE_MARKER = '--------END_OF_RESPONSE--------'
    
    attr_accessor :debug

    def initialize
      @pid, @in, @out = popen_command(find_gdb, "-n", "-q")
      execute("set prompt ")
    end
    
    def execute(command_string, timeout = nil)
      raise "GDB session is already closed" if !@pid
      puts "gdb write #{command_string.inspect}" if @debug
      @in.puts(command_string)
      @in.puts("echo \\n#{END_OF_RESPONSE_MARKER}\\n")
      done = false
      result = ""
      while !done
        begin
          if select([@out], nil, nil, timeout)
            line = @out.readline
            puts "gdb read #{line.inspect}" if @debug
            if line == "#{END_OF_RESPONSE_MARKER}\n"
              done = true
            else
              result << line
            end
          else
            close!
            done = true
            result = nil
          end
        rescue EOFError
          done = true
        end
      end
      result
    end
    
    def closed?
      !@pid
    end
    
    def close
      if !closed?
        begin
          execute("detach", 5)
          execute("quit", 5) if !closed?
        rescue Errno::EPIPE
        end
        if !closed?
          @in.close
          @out.close
          Process.waitpid(@pid)
          @pid = nil
        end
      end
    end
    
    def close!
      if !closed?
        @in.close
        @out.close
        Process.kill('KILL', @pid)
        Process.waitpid(@pid)
        @pid = nil
      end
    end
    
    def attach(pid)
      pid = pid.to_s.strip
      raise ArgumentError if pid.empty?
      result = execute("attach #{pid}")
      result !~ /(No such process|Unable to access task|Operation not permitted)/
    end
    
    def call(code)
      result = execute("call #{code}")
      result =~ /= (.*)$/
      $1
    end
    
    def program_counter
      execute("p/x $pc").gsub(/.* = /, '')
    end
    
    def current_thread
      execute("thread") =~ /Current thread is (.+?) /
      $1
    end
    
    def current_thread_backtrace
      execute("bt full").strip
    end
    
    def all_threads_backtraces
      execute("thread apply all bt full").strip
    end
    
    def ruby_backtrace
      filename = "/tmp/gdb-capture.#{@pid}.txt"
      
      orig_stdout_fd_copy = call("(int) dup(1)")
      new_stdout = call(%Q{(void *) fopen("#{filename}", "w")})
      new_stdout_fd = call("(int) fileno(#{new_stdout})")
      call("(int) dup2(#{new_stdout_fd}, 1)")
      
      # Let's hope stdout is set to line buffered or unbuffered mode...
      call("(void) rb_backtrace()")
      
      call("(int) dup2(#{orig_stdout_fd_copy}, 1)")
      call("(int) fclose(#{new_stdout})")
      call("(int) close(#{orig_stdout_fd_copy})")
      
      if File.exist?(filename)
        result = File.read(filename)
        result.strip!
        if result.empty?
          nil
        else
          result
        end
      else
        nil
      end
    ensure
      if filename
        File.unlink(filename) rescue nil
      end
    end
    
    def wait_until_exit
      execute("break _exit")
      
      signal = nil
      backtraces = nil
      snapshot = nil
      
      while true
        result = execute("continue")
        if result =~ /^Program received signal (.+?),/
          signal = $1
          backtraces = execute("thread apply all bt full").strip
          if backtraces.empty?
            backtraces = execute("bt full").strip
          end
          snapshot = yield(self) if block_given?
          
          # This signal may or may not be immediately fatal; the
          # signal might be ignored by the process, or the process
          # has some clever signal handler that fixes the state,
          # or maybe the signal handler must run some cleanup code
          # before killing the process. Let's find out by running
          # the next machine instruction.
          old_program_counter = program_counter
          result = execute("stepi")
          if result =~ /^Program received signal .+?,/
            # Yes, it was fatal. Here we don't care whether the
            # instruction caused a different signal. The last
            # one is probably what we're interested in.
            return ExitInfo.new(nil, signal, backtraces, snapshot)
          elsif result =~ /^Program (terminated|exited)/ || result =~ /^Breakpoint .*? _exit/
            # Running the next instruction causes the program to terminate.
            # Not sure what's going on but the previous signal and
            # backtrace is probably what we're interested in.
            return ExitInfo.new(nil, signal, backtraces, snapshot)
          elsif old_program_counter == program_counter
            # The process cannot continue but we're not sure what GDB
            # is telling us.
            raise "Unexpected GDB output: #{result}"
          end
          # else:
          # The signal doesn't isn't immediately fatal, so save current
          # status, continue, and check whether the process exits later.
        elsif result =~ /^Program terminated with signal (.+?),/
          if $1 == signal
            # Looks like the signal we trapped earlier
            # caused an exit.
            return ExitInfo.new(nil, signal, backtraces, snapshot)
          else
            return ExitInfo.new(nil, signal, nil, snapshot)
          end
        elsif result =~ /^Breakpoint .*? _exit /
          backtraces = execute("thread apply all bt full").strip
          if backtraces.empty?
            backtraces = execute("bt full").strip
          end
          snapshot = yield(self) if block_given?
          # On OS X, gdb may fail to return from the 'continue' command
          # even though the process exited. Kernel bug? In any case,
          # we put a timeout here so that we don't wait indefinitely.
          result = execute("continue", 10)
          if result =~ /^Program exited with code (\d+)\.$/
            return ExitInfo.new($1.to_i, nil, backtraces, snapshot)
          elsif result =~ /^Program exited normally/
            return ExitInfo.new(0, nil, backtraces, snapshot)
          else
            return ExitInfo.new(nil, nil, backtraces, snapshot)
          end
        elsif result =~ /^Program exited with code (\d+)\.$/
          return ExitInfo.new($1.to_i, nil, nil, nil)
        elsif result =~ /^Program exited normally/
          return ExitInfo.new(0, nil, nil, nil)
        else
          return ExitInfo.new(nil, nil, nil, nil)
        end
      end
    end
    
  private
    def popen_command(*command)
      a, b = IO.pipe
      c, d = IO.pipe
      if Process.respond_to?(:spawn)
        args = command.dup
        args << {
          STDIN  => a,
          STDOUT => d,
          STDERR => d,
          :close_others => true
        }
        pid = Process.spawn(*args)
      else
        pid = fork do
          STDIN.reopen(a)
          STDOUT.reopen(d)
          STDERR.reopen(d)
          b.close
          c.close
          exec(*command)
        end
      end
      a.close
      d.close
      b.binmode
      c.binmode
      [pid, b, c]
    end

    def find_gdb
      result = nil
      if ENV['GDB'] && File.executable?(ENV['GDB'])
        result = ENV['GDB']
      else
        ENV['PATH'].to_s.split(/:+/).each do |path|
          filename = "#{path}/gdb"
          if File.file?(filename) && File.executable?(filename)
            result = filename
            break
          end
        end
      end

      puts "Found gdb at: #{result}" if result

      config = defined?(RbConfig) ? RbConfig::CONFIG : Config::CONFIG
      if config['target_os'] =~ /freebsd/ && result == "/usr/bin/gdb"
        # /usr/bin/gdb on FreeBSD is broken:
        # https://github.com/FooBarWidget/crash-watch/issues/1
        # Look for a newer one that's installed from ports.
        puts "#{result} is broken on FreeBSD. Looking for an alternative..."
        result = nil
        ["/usr/local/bin/gdb76", "/usr/local/bin/gdb66"].each do |candidate|
          if File.executable?(candidate)
            result = candidate
            break
          end
        end

        if result.nil?
          raise GdbBroken,
            "*** ERROR ***: '/usr/bin/gdb' is broken on FreeBSD. " +
            "Please install the one from the devel/gdb port instead. " +
            "If you want to use another gdb"
        else
          puts "Found gdb at: #{result}" if result
          result
        end
      elsif result.nil?
        raise GdbNotFound,
          "*** ERROR ***: 'gdb' isn't installed. Please install it first.\n" +
          "       Debian/Ubuntu: sudo apt-get install gdb\n" +
          "RedHat/CentOS/Fedora: sudo yum install gdb\n" +
          "            Mac OS X: please install the Developer Tools or XCode\n" +
          "             FreeBSD: use the devel/gdb port\n"
      else
        result
      end
    end
  end
end
