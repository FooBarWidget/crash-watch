source_root = File.expand_path(File.dirname(__FILE__) + "/..")
$LOAD_PATH.unshift("#{source_root}/lib")
Thread.abort_on_exception = true

require 'crash_watch/gdb_controller'

describe CrashWatch::GdbController do
	before :each do
		@gdb = CrashWatch::GdbController.new
	end
	
	after :each do
		@gdb.close
		if @process
			Process.kill('KILL', @process.pid)
			@process.close
		end
	end
	
	def run_script_and_wait(code, snapshot_callback = nil, &block)
		@process = IO.popen(%Q{ruby -e '#{code}'}, 'w')
		@gdb.attach(@process.pid)
		thread = Thread.new do
			sleep 0.1
			if block
				block.call
			end
			@process.write("\n")
		end
		exit_info = @gdb.wait_until_exit(&snapshot_callback)
		thread.join
		return exit_info
	end
	
	describe "#execute" do
		it "executes the desired command and returns its output" do
			@gdb.execute("echo hello world").should == "hello world\n"
		end
	end
	
	describe "#attach" do
		before :each do
			@process = IO.popen("sleep 9999", "w")
		end
		
		it "returns true if attaching worked" do
			@gdb.attach(@process.pid).should be_true
		end
		
		it "returns false if the PID doesn't exist" do
			Process.kill('KILL', @process.pid)
			sleep 0.25
			@gdb.attach(@process.pid).should be_false
		end
	end
	
	describe "#wait_until_exit" do
		it "returns the expected information if the process exited normally" do
			exit_info = run_script_and_wait('STDIN.readline')
			exit_info.exit_code.should == 0
			exit_info.should_not be_signaled
		end
		
		it "returns the expected information if the process exited with a non-zero exit code" do
			exit_info = run_script_and_wait('STDIN.readline; exit 3')
			exit_info.exit_code.should == 3
			exit_info.should_not be_signaled
			exit_info.backtrace.should_not be_nil
			exit_info.backtrace.should_not be_empty
		end
		
		it "returns the expected information if the process exited because of a signal" do
			exit_info = run_script_and_wait(
				'STDIN.readline;' +
				'require "rubygems";' +
				'require "ffi";' +
				'module MyLib;' +
					'extend FFI::Library;' +
					'ffi_lib "c";' +
					'attach_function :abort, [], :void;' +
				'end;' +
				'MyLib.abort')
			exit_info.should be_signaled
			exit_info.backtrace.should =~ /abort/
		end
		
		it "ignores non-fatal signals" do
			exit_info = run_script_and_wait('trap("INT") { }; STDIN.readline; exit 2') do
				Process.kill('INT', @process.pid)
			end
			exit_info.exit_code.should == 2
			exit_info.should_not be_signaled
			exit_info.backtrace.should_not be_nil
			exit_info.backtrace.should_not be_empty
		end
		
		it "returns information of the signal that aborted the process, not information of ignored signals" do
			exit_info = run_script_and_wait(
				'trap("INT") { };' +
				'STDIN.readline;' +
				'require "rubygems";' +
				'require "ffi";' +
				'module MyLib;' +
					'extend FFI::Library;' +
					'ffi_lib "c";' +
					'attach_function :abort, [], :void;' +
				'end;' +
				'MyLib.abort'
			) do
				Process.kill('INT', @process.pid)
			end
			exit_info.should be_signaled
			exit_info.backtrace.should =~ /abort/
		end
	end
end