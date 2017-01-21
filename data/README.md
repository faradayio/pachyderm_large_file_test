# Test data sources

Our data is taken from the [OPUS][] project, which describes itself as:

> OPUS is a growing collection of translated texts from the web. In the
> OPUS project we try to convert and align free online data, to add
> linguistic annotation, and to provide the community with a publicly
> available parallel corpus. OPUS is based on open source products and the
> corpus is also delivered as an open content package. We used several
> tools to compile the current collection. All pre-processing is done
> automatically. No manual corrections have been carried out.

Individual sub-corpora are available in archives ranging from 20 MG to 33
GB, compressed.

You can find a list of download URLs we're using
in [`OPUS-URLS.txt`](./OPUS-URLS.txt) in this directory.  This is not the
complete OPUS data set, just a collection of test files.

## Downloading & reuploading to S3

We stage this data into an S3 bucket in `us-east-1` to avoid abusing the
OPUS project's bandwidth, and to speed up testing by keeping everything in
a single AWS region.

You will probably want to do this from an EC2 instance located in
`us-east-1`.

To download the data, run:

```sh
mkdir downloads
cd downloads
for URL in `cat ../OPUS-URLS.txt`; do curl -LO "$URL"; done
```

If you set up appropriate AWS credentials using `aws configure`, you can
upload your data using a command like:

```sh
cd ..
aws s3 sync downloaded/ s3://fdy-pachyderm-public-tesdata/opus
```

[OPUS]: http://opus.lingfil.uu.se/index.php
