## 1.0.1
* Set `instance_profile_credentials_retries` to 5 in the S3::Client instance to prevent "missing credentials" errors

## 1.0.0
* Remove option `client:` `from WT::S3Signer.for_s3_bucket`
* Uses a singleton s3_client by default to take advantage of AWS credentials cache

## 0.3.0
* Add option `client:` to `WT::S3Signer.for_s3_bucket`, so it's possible to inject a cached `Aws::S3::Client` instance and prevent too many requests to the AWS metadata endpoint
