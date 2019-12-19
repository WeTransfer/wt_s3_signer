require 'rspec'
require 'wt_s3_signer'
require 'aws-sdk-s3'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(File.dirname(__FILE__))

require_relative 'support/resource_allocator'

AWS_ALLOCATOR = ResourceAllocator.new

RSpec.configure do |config|
  config.order = 'random'
  AWS_ALLOCATOR.install_rspec_hooks!(config)
end
