# encoding: binary
require 'optparse'
require 'crash_watch/gdb_controller'
require 'crash_watch/version'

module CrashWatch
  class App
    def run(argv)
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: crash-watch [options] PID"
        opts.separator ""
        
        opts.separator "Options:"
        opts.on("-d", "--debug", "Show GDB commands that crash-watch sends.") do
          options[:debug] = true
        end
        opts.on("--dump", "Dump current process backtrace and exit immediately.") do
          options[:dump] = true
        end
        opts.on("-v", "--version", "Show version number.") do
          options[:version] = true
        end
        opts.on("-h", "--help", "Show this help message.") do
          options[:help] = true
        end
      end
      begin
        parser.parse!(argv)
      rescue OptionParser::ParseError => e
        puts e
        puts
        puts "Please see '--help' for valid options."
        exit 1
      end

      if options[:help]
        puts parser
        exit
      elsif options[:version]
        puts "crash-watch version #{CrashWatch::VERSION_STRING}"
        exit
      elsif argv.size != 1
        puts parser
        exit 1
      end

      begin
        gdb = CrashWatch::GdbController.new
      rescue CrashWatch::Error => e
        abort e.message
      end
      begin
        gdb.debug = options[:debug]
        
        # Ruby sometimes uses SIGVTARLM for thread scheduling.
        gdb.execute("handle SIGVTALRM noprint pass")
        
        if gdb.attach(argv[0])
          if options[:dump]
            puts "*******************************************************"
            puts "*"
            puts "*    Current thread (#{gdb.current_thread}) backtrace"
            puts "*"
            puts "*******************************************************"
            puts
            puts "    " << gdb.current_thread_backtrace.gsub(/\n/, "\n    ")
            puts
            puts
            puts "*******************************************************"
            puts "*"
            puts "*    All thread backtraces"
            puts "*"
            puts "*******************************************************"
            puts
            output = gdb.all_threads_backtraces
            output.gsub!(/\n/, "\n    ")
            output.insert(0, "    ")
            output.gsub!(/^    (Thread .*):$/, "########### \\1 ###########\n")
            puts output
          else
            puts "Monitoring PID #{argv[0]}..."
            exit_info = gdb.wait_until_exit
            puts "Process exited at #{Time.now}."
            puts "Exit code: #{exit_info.exit_code}" if exit_info.exit_code
            puts "Signal: #{exit_info.signal}" if exit_info.signaled?
            if exit_info.backtrace
              puts "Backtrace:"
              puts "    " << exit_info.backtrace.gsub(/\n/, "\n    ")
            end
          end
        else
          puts "ERROR: Cannot attach to process."
          if File.exist?("/proc/sys/kernel/yama/ptrace_scope")
            puts
            puts "This may be the result of kernel ptrace() hardening. Try disabling it with:"
            puts "  sudo sh -c 'echo 0 > /proc/sys/kernel/yama/ptrace_scope'"
            puts "See http://askubuntu.com/questions/41629/after-upgrade-gdb-wont-attach-to-process for more information."
          end
          exit 2
        end
      ensure
        gdb.close
      end
    end
  end
end
