source_root = File.expand_path(File.dirname(__FILE__) + "/..")
$LOAD_PATH.unshift("#{source_root}/lib")
Thread.abort_on_exception = true

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end
