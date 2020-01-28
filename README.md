# wt_s3_signer
An optimized AWS S3 key url signer.

## Basic usage

```ruby
s3_bucket = Aws::S3::Bucket.new('shiny-bucket-name')
ttl_seconds = 7 * 24 * 60 * 60

signer = WT::S3Signer.for_s3_bucket(s3_bucket, expires_in: ttl_seconds)
url_str = signer.presigned_get_url(object_key: full_s3_key)
      #=> https://shiny-bucket-name.s3.eu-west-1.amazonaws.com/dir/testobject?X-Amz-Algorithm...
```

## Motivation

The need of signing more then 10k S3 keys lead to the creation of this gem.

Following are the benchmarks that show why

```
Warming up --------------------------------------
WT::S3::Signer#presigned_get_url
                         9.325k i/100ms
S3Signer_SDK#presigned_get_url
                       154.000  i/100ms
Calculating -------------------------------------
WT::S3::Signer#presigned_get_url
                         81.422k (±18.9%) i/s -    391.650k in   5.042435s
S3Signer_SDK#presigned_get_url
                          1.865k (± 9.3%) i/s -      9.240k in   5.009593s

Comparison:
WT::S3::Signer#presigned_get_url:  81421.7 i/s
S3Signer_SDK#presigned_get_url:     1864.9 i/s - 43.66x  slower
```


## Disclaimer
This repo is not meant to be private. If you're reading this, is because the gem has not been completely set up.

It will fall under the Hippocratic License.
