source_root = File.expand_path(File.dirname(__FILE__) + "/..")
require "#{source_root}/test/spec_helper"
require "#{source_root}/test/controller_sharedspec"
require 'crash_watch/lldb_controller'
require 'crash_watch/utils'

if CrashWatch::Utils.lldb_installed?
  describe CrashWatch::LldbController do
    before :each do
      @gdb = CrashWatch::LldbController.new
    end

    after :each do
      @gdb.close
      if @process
        Process.kill('KILL', @process.pid)
        @process.close
      end
    end

    include_examples 'a CrashWatch controller'

    describe "#execute" do
      it "executes the desired command and returns its output" do
        expect(@gdb.execute("script print 'hello world'")).to eq("hello world\n")
      end
    end
  end
end
