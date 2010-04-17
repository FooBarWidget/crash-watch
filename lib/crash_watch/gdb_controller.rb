module CrashWatch

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
		@pid, @in, @out = popen_command("gdb", "-n", "-q")
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
		return result
	end
	
	def closed?
		return !@pid
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
		return result !~ /(No such process|Unable to access task|Operation not permitted)/
	end
	
	def call(code)
		result = execute("call #{code}")
		result =~ /= (.*)$/
		return $1
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
				return nil
			else
				return result
			end
		else
			return nil
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
				# Maybe the process will ignore this signal, so save
				# current status, continue, and check whether the
				# process exits later.
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
		return [pid, b, c]
	end
end

end