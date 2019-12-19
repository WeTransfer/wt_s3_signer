# wt_s3_signer
An optimized AWS S3 url signerFast S3 key urls signing

# Motivation
The need of signing more then 10k S3 keys lead to the creation of this signer. 
Following are the benchmarks that show why this gem exists

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


# Disclaimer
This repo is not meant to be private. If you're reading this, is because the gem has not been completely set up.

It will fall under the Hippocratic License.
