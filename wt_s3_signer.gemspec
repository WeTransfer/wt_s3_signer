lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wt_s3_signer/version'

Gem::Specification.new do |spec|
  spec.name        = "wt_s3_signer"
  spec.version     = WT::S3Signer::VERSION
  spec.date        = "2019-12-16"
  spec.summary     = "A library for signing S3 key faster"
  spec.description = "A Ruby Gem that optimize the signing of S3 keys. The gem is especially useful when dealing with a large amount of S3 object keys"
  spec.authors     = ["Luca Suriano", "Julik Tarkhanov"]
  spec.email       = ["luca.suriano@wetransfer.com", "me@julik.nl"]
  spec.files       = ["lib/wt_s3_signer.rb"]
  spec.homepage    = "https://github.com/WeTransfer/wt_s3_signer"
  spec.license     = "MIT (Hippocratic)"

  spec.add_runtime_dependency "aws-sdk-s3", "~> 1"

  spec.add_development_dependency "yard", "~> 0.9.24"
  spec.add_development_dependency "rake", "~> 13.0.1"
  spec.add_development_dependency "rspec", "~> 3.9"
  spec.add_development_dependency "rspec-benchmark", "~> 0.5.1"
  spec.add_development_dependency "rubocop"
end
