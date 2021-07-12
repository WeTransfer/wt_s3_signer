require 'openssl'
require 'digest'
require 'cgi'

# An accelerated version of the reference implementation ported
# from Python, see here:
#
# https://docs.aws.amazon.com/general/latest/gr/sigv4-signed-request-examples.html
#
# The optimisation in comparison to the ref implementation
# is that everything that can be computed once gets computed for the
# first signature being generated, and then reused. This includes
# the timestamp and everything derived from it, the signing key
# and the query string (before the signature is computed).
#
# Note that this is specifically made for the cases where one needs
# presigned URLs for multiple objects from the same bucket, with the same
# expiry. Passing the expiry via the constructor, for instance, allows us
# to cache more of the query string - saving even more time.
module WT
  class S3Signer

    # Creates a new instance of WT::S3Signer for a given S3 bucket object.
    # This object can be created in the AWS SDK using `Aws::S3::Bucket.new(my_bucket_name)`.
    # The bucket object helps resolving the bucket endpoint URL, determining the bucket
    # region and so forth.
    #
    # @param bucket[Aws::S3::Bucket] the AWS bucket resource object
    # @param client[Aws::S3::Client] an instance AWS S3 Client. It's recommended
    # to cache it in the application to avoid having too many HTTP requests to
    # the AWS instance metadata endpoint
    # @param extra_attributes[Hash] any extra keyword arguments to pass to `S3Signer.new`
    # @return [WT::S3Signer]
    def self.for_s3_bucket(bucket, **extra_attributes)
      kwargs = {}

      kwargs[:bucket_endpoint_url] = bucket.url
      kwargs[:bucket_host] = URI.parse(bucket.url).host
      kwargs[:bucket_name] = bucket.name

      resp = client.get_bucket_location(bucket: bucket.name)
      aws_region = resp.data.location_constraint

      # us-east-1 is a special AWS region (the oldest) and one
      # of the specialties is that when you ask for the region
      # of a bucket you get an empty string back instead of the
      # actual name of the region. We need to compensate for that
      # because if our region name is empty our signature will _not_
      # be accepted by S3 (but only for buckets in the us-east-1 region!)
      kwargs[:aws_region] = aws_region == "" ? "us-east-1" : aws_region

      credentials = client.config.credentials
      credentials = credentials.credentials if credentials.respond_to?(:credentials)
      kwargs[:access_key_id] = credentials.access_key_id
      kwargs[:secret_access_key] = credentials.secret_access_key
      kwargs[:session_token] = credentials.session_token

      new(**kwargs, **extra_attributes)
    rescue Aws::S3::Errors::AccessDenied, Aws::Errors::MissingCredentialsError
      # We noticed cases where errors related to AWS credentials started to happen suddenly.
      # We don't know the root cause yet, but what we can do is release the
      # @client instance because it contains a cache of credentials that in most cases
      # is no longer valid.
      @client = nil

      raise
    end

    # Creates a new instance of WT::S3Signer
    #
    # @param now[Time] The timestamp to use for the signature (the `expires_in` is also relative to that time)
    # @param expires_in[Integer] The number of seconds the URL will stay current from `now`
    # @param aws_region[String] The name of the AWS region. Also needs to be set to "us-east-1" for the respective region.
    # @param bucket_endpoint_url[String] The endpoint URL for the bucket (usually same as the bucket hostname as resolved by the SDK)
    # @param bucket_host[String] The bucket endpoint hostname (usually derived from the bucket endpoint URL)
    # @param bucket_name[String] The bucket name
    # @param access_key_id[String] The IAM access key ID
    # @param secret_access_key[String] The IAM secret access key
    # @param session_token[String,nil] The IAM session token if STS sessions are used
    def initialize(now: Time.now, expires_in:, aws_region:, bucket_endpoint_url:, bucket_host:, bucket_name:, access_key_id:, secret_access_key:, session_token:)
      @region = aws_region
      @service = "s3"

      @expires_in = expires_in
      @bucket_endpoint = bucket_endpoint_url
      @bucket_host = bucket_host
      @bucket_name = bucket_name
      @now = now.utc
      @secret_key = secret_access_key
      @access_key = access_key_id
      @session_token = session_token
    end

    # Creates a signed URL for the given S3 object key.
    # The URL is temporary and the expiration time is based on the
    # expires_in value on initialize
    #
    # @param object_key[String] The S3 key that needs a presigned url
    #
    # @raise [ArgumentError] Raises an ArgumentError if `object_key:`
    #  is empty.
    #
    # @return [String] The signed url
    def presigned_get_url(object_key:)
      # Variables that do not change during consecutive calls to the
      # method are instance variables. This way they are not assigned
      # every single time and are cached
      if (object_key.nil? || object_key == "")
        raise ArgumentError, "object_key: must not be empty"
      end

      @datestamp ||= @now.strftime("%Y%m%d")
      @amz_date ||= @now.strftime("%Y%m%dT%H%M%SZ")

      # ------ TASK 1: Create the canonical request
      # -- Step 1: define the method
      @method ||= "GET"

      # -- Step 2: create canonical uri
      # The canonical URI (the URI path) is the only thing
      # that changes depending on the object key
      canonical_uri = "/" + object_key # Might need URL escaping (!)

      # -- Step 3: create the canonical headers
      @canonical_headers ||= "host:" + @bucket_host + "\n"
      @signed_headers ||= "host"

      # -- Step 4: create the canonical query string
      @algorithm ||= "AWS4-HMAC-SHA256"
      @credential_scope ||= @datestamp + "/" + @region + "/" + @service + "/" + "aws4_request"

      @canonical_querystring_template ||= begin
        [
          "X-Amz-Algorithm=#{@algorithm}",
          "X-Amz-Credential=" + CGI.escape(@access_key + "/" + @credential_scope),
          "X-Amz-Date=" + @amz_date,
          "X-Amz-Expires=%d" % @expires_in,
          # ------- When using STS we also need to add the security token
          ("X-Amz-Security-Token=" + CGI.escape(@session_token) if @session_token),
          "X-Amz-SignedHeaders=" + @signed_headers,
        ].compact.join('&')
      end

      # -- Step 5: create payload
      @payload ||= "UNSIGNED-PAYLOAD"

      # -- Step 6: combine elements to create the canonical request
      canonical_request = [
        @method,
        canonical_uri,
        @canonical_querystring_template,
        @canonical_headers,
        @signed_headers,
        @payload
      ].join("\n")

      # ------ TASK 2: Create a String to sign
      string_to_sign = [
        @algorithm,
        @amz_date,
        @credential_scope,
        Digest::SHA256.hexdigest(canonical_request)
      ].join("\n")

      # ------ TASK 3: Calculate the signature
      @signing_key ||= derive_signing_key(@secret_key, @datestamp, @region, @service)
      signature = OpenSSL::HMAC.hexdigest("SHA256", @signing_key, string_to_sign)

      # ------ TASK 4: Add signing information to the request
      qs_with_signature = @canonical_querystring_template + "&X-Amz-Signature=" + signature

      @bucket_endpoint + canonical_uri + "?" + qs_with_signature
    end

    # AWS gems have a mechanism to cache credentials internally. So take
    # advantage of this, it's necessary to use the same client instance.
    def self.client
      @client ||= Aws::S3::Client.new(
        # The default value is 0. If the metadata service fails to respond, it
        # will raise missing credentials when used
        instance_profile_credentials_retries: 5,
      )
    end

    def self.client=(client)
      @client = client
    end

    private

    def derive_signing_key(key, datestamp, region, service)
      prefixed_key = "AWS4" + key
      k_date = hmac_bytes(prefixed_key, datestamp)
      k_region = hmac_bytes(k_date, region)
      k_service = hmac_bytes(k_region, service)
      hmac_bytes(k_service, "aws4_request")
    end

    def hmac_bytes(key, data)
      OpenSSL::HMAC.digest("SHA256", key, data)
    end
  end
end
