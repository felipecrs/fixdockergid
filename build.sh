#!/bin/bash

set -euxo pipefail

rm -rf dist

docker buildx build --target=dist --platform=amd64 -o . .
docker buildx build --target=dist --platform=arm64 -o . .

set +x

echo "Release on GitHub with:" >&2
# shellcheck disable=SC2016
echo '  gh release create v${VERSION?} --title v${VERSION} dist/*' >&2

echo "Push to Docker Hub with:" >&2
# shellcheck disable=SC2016
cat <<'EOF' >&2
  docker run --privileged --rm --pull=always tonistiigi/binfmt --install arm64 \
  && docker buildx rm --force multi-arch-builder \
  && docker buildx create --name multi-arch-builder \
  && docker buildx build . --builder multi-arch-builder --pull \
    --tag felipecrs/fixdockergid:latest \
    --tag felipecrs/fixdockergid:${VERSION?} \
    --platform=linux/amd64,linux/arm64  \
    --push
EOF
