# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'thrifter/version'

Gem::Specification.new do |spec|
  spec.name          = "thrifter"
  spec.version       = Thrifter::VERSION
  spec.authors       = ["ahawkins"]
  spec.email         = ["adam@hawkins.io"]
  spec.summary       = %q{Production ready Thrift client with improved semantics}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/saltside/thrifter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "thrift"
  spec.add_dependency "thrift-base64"
  spec.add_dependency "thrift-validator"
  spec.add_dependency "statsd-ruby"
  spec.add_dependency "concord"
  spec.add_dependency "middleware"
  spec.add_dependency "connection_pool"
  spec.add_dependency "tnt"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "sidekiq", "~> 4.2"
  spec.add_development_dependency "sidekiq-thrift_arguments"
  spec.add_development_dependency "eventmachine"
end
