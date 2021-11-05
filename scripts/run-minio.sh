#!/bin/bash

# Runs a minio server as a docker container with default credentials (minioadmin/minioadmin)
# and a single bucket ("bucket").

docker run --rm -t -i \
  --name minio-bucketstore \
  -p 9000:9000 \
  -p 9001:9001 \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  -e "MINIO_REGION_NAME=us-east-1" \
  --entrypoint bash \
  quay.io/minio/minio -c "\
  mkdir -p /data/bucket && \
  minio server /data --console-address \":9001\"
  "
