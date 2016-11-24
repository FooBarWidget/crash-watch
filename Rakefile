$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/lib"))
require 'crash_watch/version'
require 'tmpdir'

PACKAGE_NAME    = "crash-watch"
PACKAGE_VERSION = CrashWatch::VERSION_STRING
MAINTAINER_NAME  = "Hongli Lai"
MAINTAINER_EMAIL = "hongli@phusion.nl"

desc "Run unit tests"
task :test do
  ruby "-S rspec -f documentation -c test/*_spec.rb"
end

desc "Build, sign & upload gem"
task 'package:release' do
  sh "git tag -s release-#{PACKAGE_VERSION}"
  sh "gem build #{PACKAGE_NAME}.gemspec"
  puts "Proceed with pushing tag to Github and uploading the gem? [y/n]"
  if STDIN.readline == "y\n"
    sh "git push origin release-#{PACKAGE_VERSION}"
    sh "gem push #{PACKAGE_NAME}-#{PACKAGE_VERSION}.gem"
  else
    puts "Did not upload the gem."
  end
end


##### Utilities #####

def string_option(name, default_value = nil)
  value = ENV[name]
  if value.nil? || value.empty?
    return default_value
  else
    return value
  end
end

def boolean_option(name, default_value = false)
  value = ENV[name]
  if value.nil? || value.empty?
    return default_value
  else
    return value == "yes" || value == "on" || value == "true" || value == "1"
  end
end
