Gem::Specification.new do |spec|
  spec.name        = 'wt_s3_signer'
  spec.version     = '0.0.1'
  spec.date        = '2019-12-16'
  spec.summary     = ""
  spec.description = ""
  spec.authors     = ['Luca Suriano', 'Julik Tarkhanov'] 
  spec.email       = 'nick@quaran.to'
  spec.files       = ["lib/wt_s3_signer.rb"]
  spec.homepage    = 'https://github.com/WeTransfer/wt_s3_signer'
  spec.license     = 'MIT (Hippocratic)'

  spec.add_runtime_dependency 'aws-sdk-s3', '~> 1'
  spec.add_development_dependency 'rspec', '~> 3.9'
end
