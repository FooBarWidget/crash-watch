$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/lib"))
require 'crash-watch/version'

desc "Build, sign & upload gem"
task 'package:release' do
	sh "git tag -s release-#{CrashWatch::VERSION_STRING}"
	sh "gem build crash-watch.gemspec --sign --key 0x0A212A8C"
	puts "Proceed with pushing tag to Github and uploading the gem? [y/n]"
	if STDIN.readline == "y\n"
		sh "git push origin release-#{CrashWatch::VERSION_STRING}"
		sh "gem push crash-watch-#{CrashWatch::VERSION_STRING}.gem"
	else
		puts "Did not upload the gem."
	end
end
