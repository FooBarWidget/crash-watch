source_root = File.expand_path(File.dirname(__FILE__) + "/..")
require "#{source_root}/test/spec_helper"
require "#{source_root}/test/controller_sharedspec"
require 'crash_watch/utils'

if CrashWatch::Utils.gdb_installed?
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

    include_examples 'a CrashWatch controller'
  end
end
