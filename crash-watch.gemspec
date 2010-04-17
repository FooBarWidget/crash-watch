require File.expand_path('lib/crash_watch/version', File.dirname(__FILE__))

Gem::Specification.new do |s|
	s.name = "crash-watch"
	s.version = CrashWatch::VERSION_STRING
	s.authors = ["Hongli Lai"]
	s.date = "2010-04-16"
	s.description = "Monitor processes and display useful information when they crash."
	s.summary = "Monitor processes and display useful information when they crash"
	s.email = "hongli@phusion.nl"
	s.files = Dir[
		"README.markdown",
		"LICENSE.txt",
		"crash-watch.gemspec",
		"bin/**/*",
		"lib/**/*",
		"test/**/*"
	]
	s.homepage = "http://github.com/FooBarWidget/crash-watch"
	s.rdoc_options = ["--charset=UTF-8"]
	s.executables = ["crash-watch"]
	s.require_paths = ["lib"]
	s.add_development_dependency("ffi")
	s.add_development_dependency("rspec")
end

