# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ted_talk/version'

Gem::Specification.new do |gem|
  gem.name          = "ted_talk"
  gem.version       = TedTalk::VERSION
  gem.authors       = ["Yoichiro Hasebe"]
  gem.email         = ["yohasebe@gmail.com"]
  gem.description   = "TedTalk helps download TED talk video "
  gem.description  += "and covert it to MP3 that can be conveniently used for English learning"
  gem.summary       = "TED talk downloader and converter for English learners"
  gem.homepage      = "http://github.com/yohasebe/ted_talk"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_development_dependency "minitest"
  gem.add_runtime_dependency "progressbar"
  gem.add_runtime_dependency "json"
  gem.add_runtime_dependency "taglib"
  gem.add_runtime_dependency "nokogiri"  
end
