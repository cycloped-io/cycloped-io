Gem::Specification.new do |s|
  s.name = "syntax"
  s.version = "0.0.1"
  s.date = "#{Time.now.strftime("%Y-%m-%d")}"
  s.required_ruby_version = '>= 1.9.2'
  s.authors = ['Krzysztof Wrobel', 'Aleksander Pohl']
  s.email   = ["apohllo@o2.pl"]
#  s.homepage    = "http://github.com/apohllo/rod"
  s.summary = "English syntax manipulation"
  s.description = "Library for manipulating sentence parses produced by Stanford NLP"

  s.rubyforge_project = "syntax"
#  s.rdoc_options = ["--main", "README.rdoc"]

  s.files         = `git ls-files .`.split("\n")
#  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
#  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_path = "lib"

  s.add_dependency("rubytree")
end
