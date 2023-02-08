#!/bin/bash

# Runs a GCP simulator as a docker container and a single bucket ("bucket").

docker run --rm -t -i \
  -p 9023:9023 \
  --name fake-gcs-server \
  --entrypoint /bin/sh \
  fsouza/fake-gcs-server -c "\
    mkdir -p /data/bucket &&
    /bin/fake-gcs-server -scheme=http -backend=filesystem -filesystem-root=/data -port=9023
    "
