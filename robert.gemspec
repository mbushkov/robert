$:.unshift File.expand_path("../lib", __FILE__)
require 'robert/version'

Gem::Specification.new do |s|
  s.name = "robert"
  s.version = Robert::Version::STRING
  s.platform = Gem::Platform::RUBY
  s.authors = ["Michael Bushkov"]
  s.email = "realbushman@gmail.com"
  s.homepage = "https://github.com/mbushkov/robert"
  s.summary = "robert-#{Robert::Version::STRING}"
  s.description = "Generic configuration system"

  s.rubygems_version = "1.3.7"

  s.add_development_dependency "aruba"
  s.add_development_dependency "cucumber"
  s.add_development_dependency "flexmock"
  s.add_development_dependency "rspec"

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_path = "lib"
end
