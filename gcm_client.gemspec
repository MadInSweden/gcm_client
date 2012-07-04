# -*- encoding: utf-8 -*-
require File.expand_path('../lib/gcm_client/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "gcm_client"
  gem.version     = GcmClient::VERSION
  gem.authors     = ["Anders Carling"]
  gem.email       = ["anders.carling@footballaddicts.com"]
  gem.homepage    = ""
  gem.summary     = %q{Library for sending Google Cloud Messages to Android devices from Ruby}
  gem.description = %q{Library for sending Google Cloud Messages to Android devices from Ruby}

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "yajl-ruby"
  gem.add_dependency "httpclient"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "webmock"
end
