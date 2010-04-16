module CrashWatch

class GdbController
	class ExitInfo
		attr_reader :exit_code, :signal, :backtrace
		
		def initialize(exit_code, signal, backtrace)
			@exit_code = exit_code
			@signal = signal
			@backtrace = backtrace
		end
		
		def signaled?
			!!@signal
		end
	end
	
	END_OF_RESPONSE_MARKER = '--------END_OF_RESPONSE--------'
	
	attr_accessor :debug
	
	def initialize
		@pid, @in, @out = popen_command("gdb", "-n", "-q")
		execute("set prompt ")
	end
	
	def execute(command_string)
		puts "gdb write #{command_string.inspect}" if @debug
		@in.puts(command_string)
		@in.puts("echo \\n#{END_OF_RESPONSE_MARKER}\\n")
		done = false
		result = ""
		while !done
			begin
				line = @out.readline
				puts "gdb read #{line.inspect}" if @debug
				if line == "#{END_OF_RESPONSE_MARKER}\n"
					done = true
				else
					result << line
				end
			rescue EOFError
				done = true
			end
		end
		return result
	end
	
	def close
		if @pid
			begin
				execute("detach")
				execute("quit")
			rescue Errno::EPIPE
			end
			@in.close
			@out.close
			Process.waitpid(@pid)
			@pid = nil
		end
	end
	
	def attach(pid)
		pid = pid.to_s.strip
		raise ArgumentError if pid.empty?
		result = execute("attach #{pid}")
		return result !~ /(No such process|Unable to access task)/
	end
	
	def wait_until_exit
		execute("break _exit")
		
		signal = nil
		backtraces = nil
		
		while true
			result = execute("continue")
			if result =~ /^Program received signal (.+?),/
				signal = $1
				backtraces = execute("thread apply all bt full").strip
				if backtraces.empty?
					backtraces = execute("bt full").strip
				end
				# Maybe the process will ignore this signal, so save
				# current status, continue, and check whether the
				# process exits later.
			elsif result =~ /^Program terminated with signal (.+?),/
				if $1 == signal
					# Looks like the signal we trapped earlier
					# caused an exit.
					return ExitInfo.new(nil, signal, backtraces)
				else
					return ExitInfo.new(nil, signal, nil)
				end
			elsif result =~ /^Breakpoint .*? _exit /
				backtraces = execute("thread apply all bt full").strip
				if backtraces.empty?
					backtraces = execute("bt full").strip
				end
				result = execute("continue")
				if result =~ /^Program exited with code (\d+)\.$/
					return ExitInfo.new($1.to_i, nil, backtraces)
				elsif result =~ /^Program exited normally/
					return ExitInfo.new(0, nil, backtraces)
				else
					return ExitInfo.new(nil, nil, backtraces)
				end
			elsif result =~ /^Program exited with code (\d+)\.$/
				return ExitInfo.new($1.to_i, nil, nil)
			elsif result =~ /^Program exited normally/
				return ExitInfo.new(0, nil, nil)
			else
				return ExitInfo.new(nil, nil, nil)
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
		return [pid, b, c]
	end
end

end