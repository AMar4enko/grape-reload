# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'grape/reload/version'

Gem::Specification.new do |spec|
  spec.name          = "grape-reload"
  spec.version       = Grape::Reload::VERSION
  spec.authors       = ["AMar4enko"]
  spec.email         = ["amar4enko@gmail.com"]
  spec.summary       = 'Grape autoreload gem'
  spec.homepage      = "https://github.com/AlexYankee/grape-reload"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "grape", ">= 0.10.1"
  spec.add_runtime_dependency "rack", ">= 1.5.2"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "terminal-notifier-guard"
  spec.add_development_dependency "rspec-nc"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-remote"
  spec.add_development_dependency "pry-nav"
end
