# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ncio/version'

Gem::Specification.new do |spec|
  spec.name          = "ncio"
  spec.version       = Ncio::VERSION
  spec.authors       = ["Jeff McCune"]
  spec.email         = ["jeff@openinfrastructure.co"]

  spec.summary       = 'Puppet Node Classifier backup / restore / transform'
  spec.description   = 'ncio is a small command line utility to backup, '\
    'restore, and transform Puppet Enterprise Node Classification groups.'
  spec.homepage      = "https://www.openinfrastructure.co"
  spec.license       = "MIT"

  # YARD Documentation
  spec.has_rdoc      = 'yard'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "yard", "~> 0.8.7"
  spec.add_development_dependency "bluecloth", "~> 2.2.0"
  spec.add_development_dependency "rubocop", "~> 0.41.1"
  spec.add_development_dependency "simplecov", "~> 0.11.2"
end
