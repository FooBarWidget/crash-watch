require 'shellwords'

shared_examples_for 'a CrashWatch controller' do
  def run_script_and_wait(code, snapshot_callback = nil, &block)
    @process = IO.popen(%Q{exec ruby -e #{Shellwords.escape code}}, 'w')
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
    exit_info
  end

  describe "#execute" do
    it "executes the desired command and returns its output" do
      expect(@gdb.execute("echo hello world")).to eq("hello world\n")
    end
  end

  describe "#attach" do
    before :each do
      @process = IO.popen("sleep 9999", "w")
    end

    it "returns true if attaching worked" do
      expect(@gdb.attach(@process.pid)).to be_truthy
    end

    it "returns false if the PID doesn't exist" do
      Process.kill('KILL', @process.pid)
      sleep 0.25
      expect(@gdb.attach(@process.pid)).to be_falsey
    end
  end

  describe "#wait_until_exit" do
    it "returns the expected information if the process exited normally" do
      exit_info = run_script_and_wait('STDIN.readline')
      expect(exit_info.exit_code).to eq(0)
      expect(exit_info).not_to be_signaled
    end

    it "returns the expected information if the process exited with a non-zero exit code" do
      exit_info = run_script_and_wait('STDIN.readline; exit 3')
      expect(exit_info.exit_code).to eq(3)
      expect(exit_info).not_to be_signaled
      expect(exit_info.backtrace).not_to be_nil
      expect(exit_info.backtrace).not_to be_empty
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
      expect(exit_info).to be_signaled
      expect(exit_info.backtrace).to match(/abort/)
    end

    it "ignores non-fatal signals" do
      exit_info = run_script_and_wait('trap("INT") { }; STDIN.readline; exit 2') do
        Process.kill('INT', @process.pid)
      end
      expect(exit_info.exit_code).to eq(2)
      expect(exit_info).not_to be_signaled
      expect(exit_info.backtrace).not_to be_nil
      expect(exit_info.backtrace).not_to be_empty
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
      expect(exit_info).to be_signaled
      expect(exit_info.backtrace).to match(/abort/)
    end
  end
end
