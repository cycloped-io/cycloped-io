# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rlp/wiki/version"

Gem::Specification.new do |s|
  s.name        = "rlp-wiki"
  s.version     = Rlp::Wiki::VERSION
  s.authors     = ["Aleksander Pohl"]
  s.email       = ["apohllo@o2.pl"]
  s.homepage    = ""
  s.summary     = %q{Ruby library for accessing semantic data extracted from Wikipedia}
  s.description = %q{Ruby library for accessing semantic data extracted from Wikipedia}

  s.rubyforge_project = "rlp-wiki"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  #s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('ZenTest')
  s.add_dependency('cycr', '~> 0.2.0')
  s.add_dependency('rod', '~> 0.7.2.4')
  s.add_dependency('syntax')
end
