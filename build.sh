#!/bin/bash

set -euxo pipefail

docker buildx build --target=bin --platform=amd64 -o . .
