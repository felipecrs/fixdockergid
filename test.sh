#!/bin/bash

set -euxo pipefail

name=fixdockergid-test
docker build -t $name -f Dockerfile .
docker run --rm --name $name -v /var/run/docker.sock:/var/run/docker.sock $name bash -exc \
  'id -u; id -g; docker version'
