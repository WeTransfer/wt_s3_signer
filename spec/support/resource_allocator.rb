require 'set'

# The resource allocator manages mutable resources that we create during test runs,
# such as AWS buckets. It is kind of a tiny implementation of Go's `defer`, and ot
# creates an allocation group for each level of RSpec's expectation pre/post actions.
# Specifically
#
#  resources on :suite level
#    resources on :all level
#     resources on :all level for a context
#       resources on :each level for a specific example
#       resources allocated during test
#
# When a scope is finished in RSpec, the allocation group will be "popped" from the stack
# and all resources for which cleanup has been defined during allocation will be deleted
# and cleaned up. This can be used for all sorts of test resources, but mostly for S3 buckets
# and SQS queues and the like. The allocator will ensure that the cleanup blocks are
# all called in the reverse order they were called for the case there are resource
# dependencies
#
# * each allocated resource is named in a unique and non ambiguous way
# * that each process uses it's own numbering sequence for allocated resource names
# * that resources are named with date and time in the name so if they are leaked you can see when they got created
class ResourceAllocator
  def initialize(common_prefix: "wt-nbt")
    @ctr = 0
    @common_prefix = common_prefix
    @allocation_groups = [[]]
    @names = Set.new
    @test_time_str = Time.now.utc.strftime("%Y%m%d%H%M")
    @common = alphanumeric_seed(4)
  end

  def computed_prefix
    "#{@common_prefix}-#{@test_time_str}-#{@common}-...-..."
  end

  def resource_count
    @allocation_groups.map(&:length).inject(&:+).to_i
  end

  def push_alloc_group
    @allocation_groups << []
  end

  def alphanumeric_seed(n_chars)
    alphabet = ('a'..'z').to_a + ('0'..'9').to_a
    n_chars.times.map { alphabet[SecureRandom.random_number(alphabet.length)] }.join
  end
  
  def alloc_resource_name
    loop do
      @ctr += 1
      salt = alphanumeric_seed(5) # even more collision prevention
      generated_name = "#{@common_prefix}-#{@test_time_str}-#{@common}-#{@ctr}-#{salt}"
      unless @names.include?(generated_name)
        @names << generated_name
        return generated_name
      end
    end
  end

  def create_sqs_queue_name_and_url
    name = alloc_resource_name

    client = Aws::SQS::Client.new
    resp = client.create_queue(queue_name: name)
    url = resp.queue_url

    cleanup_later(name: name, resource_type: :s3_bucket) do
      client = Aws::SQS::Client.new
      client.delete_queue(queue_url: url) rescue nil
    end

    [name, url]
  end

  def create_s3_bucket_and_name
    name = alloc_resource_name
    bucket_resource = Aws::S3::Bucket.new(name)
    bucket_resource.create
    cleanup_later(name: name, resource_type: :s3_bucket) do
      bucket_resource.delete! rescue nil
    end
    [bucket_resource, name]
  end

  def cleanup_later(resource_type: :unknown, name: alloc_resource_name, &resource_cleanup)
    # Store the block for later, and return the name immediately
    @allocation_groups << [] unless @allocation_groups.any?
    @allocation_groups.last << [name, resource_type, resource_cleanup]
    name
  end

  def pop_alloc_group
    resources_to_remove = @allocation_groups.pop || []
    resources_to_remove.reverse_each do |name, resource_type, cleanup_proc|
      cleanup_proc.call(name, resource_type)
    end
  end

  def cleanup_all
    pop_alloc_group while @allocation_groups.any?
  end

  def install_rspec_hooks!(config)
    this_allocator = self
    config.before :suite do
      this_allocator.push_alloc_group
    end
  
    config.before :all do
      this_allocator.push_alloc_group
    end
  
    config.after :all do
      this_allocator.pop_alloc_group
    end
  
    config.around :each do |example|
      this_allocator.push_alloc_group
      example.run
      this_allocator.pop_alloc_group
    end
    
    config.after :suite do
      this_allocator.cleanup_all
    end
  end
end
