require 'spec_helper'
require 'net/http'

shared_context 'signer_bucket' do
  let(:bucket_and_name) { AWS_ALLOCATOR.create_s3_bucket_and_name }
  let(:bucket) { bucket_and_name[0] }
  let(:bucket_name) { bucket_and_name[1] }
  let(:client) {
    client = Aws::S3::Client.new
  }
  let(:bucket_region) { 
    resp = client.get_bucket_location(bucket: bucket_name)
    resp.data.location_constraint
  }
  let(:creds) { client.config.credentials }
  let(:signer) { described_class.new(aws_region: bucket_region, expires_in: 173, s3_bucket_name: bucket_name, aws_credentials: creds) }
end

describe WT::S3Signer do
  include_context 'signer_bucket'

  it 'WT::Signer is faster than Aws::S3::Presigner' do
    allow(WT::S3Signer).to receive(:create_bucket).and_return(bucket)

    bucket.object('dir/testobject').put(body: 'is here')

    expect { bucket.object('dir/testobject').presigned_url(:get, expires_in: 173) }.to perform_at_least(1000).ips
    expect { signer.presigned_get_url(object_key: 'dir/testobject') }.to perform_at_least(100000).within(0.4).warmup(0.2).ips
  end

  it 'signs an s3 key' do
    allow(WT::S3Signer).to receive(:create_bucket).and_return(bucket)

    bucket.object('dir/testobject').put(body: 'is here')
    presigned_url = signer.presigned_get_url(object_key: 'dir/testobject')

    expect(presigned_url).to include("X-Amz-Expires=173")
  end

  it 'signs a valid s3 key' do
    allow(WT::S3Signer).to receive(:create_bucket).and_return(bucket)

    bucket.object('dir/testobject').put(body: 'is here')
    presigned_url = signer.presigned_get_url(object_key: 'dir/testobject')

    uri = URI(presigned_url)
    res = Net::HTTP.get_response(uri)

    expect(res.code).to eq("200")
  end

  it 'throws an exception if no key is used for signing' do 
    expect{signer.presigned_get_url(object_key: '')}.to raise_error(ArgumentError)
  end

end
