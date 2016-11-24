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

  describe "#attach" do
    before :each do
      @process = IO.popen("exec ruby -e 'sleep 9999'", "w")
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
end
