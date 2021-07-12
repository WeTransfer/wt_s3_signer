require 'spec_helper'
require 'net/http'

shared_context 'signer_bucket' do
  let(:bucket) { AWS_ALLOCATOR.create_s3_bucket_and_name.first }
  let(:signer) { described_class.for_s3_bucket(bucket, expires_in: 173) }
end

describe WT::S3Signer do
  include_context 'signer_bucket'

  it 'WT::Signer is faster than Aws::S3::Presigner' do
    allow(WT::S3Signer).to receive(:create_bucket).and_return(bucket)

    bucket.object('dir/testobject').put(body: 'is here')

    # These values come from previous performance measurements ran on nu_backend
    expect { bucket.object('dir/testobject').presigned_url(:get, expires_in: 173) }.to perform_at_least(1000).ips
    expect { signer.presigned_get_url(object_key: 'dir/testobject') }.to perform_at_least(40_000).ips
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

  describe '.for_s3_bucket' do
    it 'uses a singleton instance of s3 client' do
      allow(WT::S3Signer).to receive(:create_bucket).and_return(bucket)
      bucket.object('dir/testobject').put(body: 'is here')

      # If other tests run before, they might instantiate the singleton client,
      # so it's acceptable for Aws::S3::Client to not receive :new
      expect(Aws::S3::Client).to receive(:new).at_most(:once).and_call_original

      signer1 = described_class.for_s3_bucket(bucket, expires_in: 174)
      signer2 = described_class.for_s3_bucket(bucket, expires_in: 175)

      presigned_url1 = signer1.presigned_get_url(object_key: 'dir/testobject')
      presigned_url2 = signer2.presigned_get_url(object_key: 'dir/testobject')

      expect(presigned_url1).to include("X-Amz-Expires=174")
      expect(presigned_url2).to include("X-Amz-Expires=175")
    end

    it 'releases the singleton client when AWS raises an access denied error' do
      s3_client = Aws::S3::Client.new(stub_responses: true)
      described_class.client = s3_client

      s3_client.stub_responses(:get_object, body: 'is here')

      # just to set @client internally
      described_class.for_s3_bucket(bucket, expires_in: 174)

      # now, let's simulate an error on AWS
      s3_client.stub_responses(
        :get_bucket_location,
        Aws::S3::Errors::AccessDenied.new(_context = nil, _message = nil)
      )

      # exercise again
      expect do
        described_class.for_s3_bucket(bucket, expires_in: 174)
      end.to raise_error(Aws::S3::Errors::AccessDenied)

      expect(described_class.client).not_to be(s3_client)
    end
  end
end
