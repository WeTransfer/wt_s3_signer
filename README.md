# wt_s3_signer
An optimized AWS S3 key url signer.

## Basic usage

```ruby
s3_bucket_region = "eu-west-1"
default_aws_credentials = Aws::S3::Client.new.config.credentials
s3_presigned_url_ttl = 7 * 24 * 60 * 60

signer = WT::S3Signer.new(aws_region: s3_bucket_region,
      s3_bucket_name: "my-new-bucket",
      aws_credentials: default_aws_credentials,
      expires_in: s3_presigned_url_ttl)
      
presigned_get_url = signer.presigned_get_url(object_key: full_s3_key) 
      #=> https://shiny-bucket-name.s3.eu-west-1.amazonaws.com/dir/testobject?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIA5H3NMPY62LFQKVHN%2F20191220%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-Date=20191220T142130Z&X-Amz-Expires=173&X-Amz-Security-Token=FwoGZXIvYXdzEJD%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaDLTRF%2BCAVya99FECxyKzAauMjBy%2B1tPoQLk1MAMZ40%2BW0Q1B54ZLnhSYZqrEB8GwE1ZvYu6rOIjnVpI6DFDXCQEDmKg3qAg7LXP6kkTXfbaXuuw0ddRsPujiIX9Rdjiw4w5Kx5pgktWeJp8R6b6s9zXJU%2BiG8tvEr9SP9PdRKCmAEWSt%2BqFJClazQgX%2FZD7LG9Tzc1d9JRdsu1fNJV24krZLhg7BfKv%2B8vVIH3O6HZLzFOdY9%2Bx4v2lgXSBPwCPa10HuKOmx8%2B8FMi3710%2BMgJUdTRig%2FkbkQsGpEScXe6%2F%2Fuh1unhDUKyl4f5skGZMch2M6fNNCpPA%3D&X-Amz-SignedHeaders=host&X-Amz-Signature=8fb04553a1f00e4e67e6000c142861700c8a7dfe2d27767369805798f4fc0c8d
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
