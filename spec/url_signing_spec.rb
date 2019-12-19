require 'spec_helper'

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

  it 'signs an s3 key' do
    bucket.object('dir/testobject').put(body: 'is here')
 
    allow(WT::S3Signer).to receive(:create_bucket).and_return(bucket)

    presigned_url = signer.presigned_get_url(object_key: 'dir/testobject')

    expect(presigned_url).to include("X-Amz-Expires=173")
  end

  it 'throws an exception if no key is used for signing' do 
    expect{signer.presigned_get_url(object_key: '')}.to raise_error(ArgumentError)
  end
end
