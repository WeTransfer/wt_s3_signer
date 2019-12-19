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

    # @param [String] aws_region The region of the bucket. If empty it defaults to
    #   us-east-1
    # @param [String] s3_bucket_name The bucket name
    # @param [Integer] expires_in The number of seconds before the presigned URL
    #   expires 
    # @param [Aws::Credentials] aws_credentials 
    #
    def initialize(aws_region:, s3_bucket_name:, expires_in:, aws_credentials: :AUTO)
      # us-east-1 is a special AWS region (the oldest) and one
      # of the specialties is that when you ask for the region
      # of a bucket you get an empty string back instead of the
      # actual name of the region. We need to compensate for that
      # because if our region name is empty our signature will _not_
      # be accepted by S3 (but only for buckets in the us-east-1 region!)
      @region = aws_region == "" ? "us-east-1" : aws_region
      @service = "s3"

      @expires_in = expires_in
      bucket = create_bucket(s3_bucket_name)
      @bucket_endpoint = bucket.url
      @bucket_host = URI.parse(@bucket_endpoint).host
      @bucket_name = s3_bucket_name
      @now = Time.now.utc
      @secret_key = aws_credentials.credentials.secret_access_key
      @access_key = aws_credentials.credentials.access_key_id
      @session_token = aws_credentials.credentials.session_token
    end

    def create_bucket(bucket_name)
      Aws::S3::Bucket.new(bucket_name)
    end

    # @param [String] object_key The S3 key that needs a presigned url
    #
    # @raise [ArgumentError] Raises an ArgumentError if `:object_key`
    #  is empty.
    #
    def presigned_get_url(object_key:)
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
