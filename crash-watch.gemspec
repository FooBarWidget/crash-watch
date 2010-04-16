Gem::Specification.new do |s|
	s.name = "crash-watch"
	s.version = "1.0.0"
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
	s.homepage = %q{http://money.rubyforge.org/}
	s.rdoc_options = ["--charset=UTF-8"]
	s.executables = ["crash-watch"]
	s.require_paths = ["lib"]
	s.add_development_dependency("ffi")
	s.add_development_dependency("rspec")
end

