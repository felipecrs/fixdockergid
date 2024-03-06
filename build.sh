#!/bin/bash

set -euxo pipefail

rm -rf dist

docker run --privileged --rm --pull=always tonistiigi/binfmt --install arm64

export BUILDX_BUILDER="fixdockergid"

docker buildx create --name "${BUILDX_BUILDER}"
trap 'docker buildx rm --force "${BUILDX_BUILDER}"' EXIT

docker buildx build --target=dist --platform=amd64 -o . .
docker buildx build --target=dist --platform=arm64 -o . .

docker buildx build . --platform=linux/amd64,linux/arm64

set +x

if [[ -z "${VERSION:-}" ]]; then
  echo "Set VERSION if you want to publish" >&2
  exit 1
fi

set -x

gh release create "v${VERSION}" --title "v${VERSION}" dist/*

docker buildx build . --platform=linux/amd64,linux/arm64 \
  --tag=felipecrs/fixdockergid:latest \
  --tag="felipecrs/fixdockergid:${VERSION}" \
  --push
