#!/bin/bash

set -euxo pipefail

DOCKER_BUILDKIT=1 docker build --target=bin --platform=amd64 -o . .
