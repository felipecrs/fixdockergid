#!/bin/bash

set -euxo pipefail

name=fixdockergid-test
uid_gid="$(id -u):$(id -g)"

function tests() {
  docker rm -f "${name}"

  # Confirm fixuid is working
  docker run --rm --name "${name}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" "${name}" \
    whoami | grep '^rootless$'
  docker run --rm --name "${name}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" "${name}" \
    groups | grep '^rootless docker$'

  # Confirm fixdockergid is working
  docker run --rm --name "${name}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" "${name}" \
    docker version --format '{{.Server.Version}}'

  # Confirm it doesn't work without fixdockergid
  set +o pipefail
  docker run --rm --name "${name}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" --entrypoint= "${name}" \
    docker version --format '{{.Server.Version}}' 2>&1 |
    grep 'dial unix /var/run/docker.sock: connect: permission denied'
  set -o pipefail

  # Test docker exec
  docker run --name "${name}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" --group-add docker -d "${name}" sleep infinity
  sleep 1s
  docker exec "${name}" docker version --format '{{.Server.Version}}'
  docker rm -f "${name}"

  # Confirm it doesn't work without --group-add
  docker run --name "${name}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" -d "${name}" sleep infinity
  sleep 1s
  set +o pipefail
  docker exec "${name}" docker version --format '{{.Server.Version}}' 2>&1 |
    grep 'dial unix /var/run/docker.sock: connect: permission denied'
  set -o pipefail
  docker rm -f "${name}"
}

# Exercise happy paths (i.e. uid and gid are equal to host uid and gid already)
current_uid="$(id -u)"
current_docker_gid="$(getent group docker | cut -d: -f3)"

docker build -t "${name}" -f Dockerfile . \
  --build-arg USER_UID="${current_uid}" --build-arg DOCKER_GID="${current_docker_gid}"

tests

# Exercise non-happy paths
test_uid="$((current_uid + 1))"
test_docker_gid="$((current_docker_gid - 1))"

# Ensure UID in image is different from host UID to exercise fixuid
# Ensure docker GID in image is different from host docker GID to exercise fixdockergid
docker build -t "${name}" -f Dockerfile . \
  --build-arg USER_UID="${test_uid}" --build-arg DOCKER_GID="${test_docker_gid}"

tests
