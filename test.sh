#!/bin/bash

set -euxo pipefail

readonly container_name="fixdockergid-test"

if [[ "${RUN_HERE:-false}" == false ]]; then
  function run_in_dind() {
    local dind_username="${DIND_USERNAME:-}"

    local extra_build_args=()
    if [[ -n "${dind_username}" ]]; then
      extra_build_args+=("--build-arg=USERNAME=${dind_username}")
    fi

    docker build -t "${container_name}" -f Dockerfile . --target=dind "${extra_build_args[@]}"
    docker rm -f "${container_name}" --volumes

    # create volume to retain cache if not already created
    if ! docker volume ls -q | grep -q "^${container_name}$"; then
      docker volume create "${container_name}"
    fi

    docker run --name="${container_name}" --privileged \
      --workdir=/wd --volume="${PWD}:/wd" \
      --volume="${container_name}:/var/lib/docker" \
      --detach \
      "${container_name}"
    sleep 1s

    # Restart from container
    extra_exec_args=()
    if [[ -n "${dind_username}" ]]; then
      extra_exec_args+=("--env=DIND_USERNAME=${dind_username}")
    fi

    docker exec --env=RUN_HERE=true "${extra_exec_args[@]}" "${container_name}" ./test.sh
  }

  run_in_dind

  # Do the exact same thing but this time call the user docker
  export DIND_USERNAME="docker"
  run_in_dind
  unset DIND_USERNAME

  docker rm -f "${container_name}" --volumes

  exit 0
fi

current_uid="$(id -u)"
current_gid="$(id -g)"
# get docker gid from /var/run/docker.sock
current_docker_gid="$(stat -c '%g' /var/run/docker.sock)"
readonly current_uid current_gid current_docker_gid

function tests() {
  local uid_gid="${uid_gid:-"${current_uid}:${current_gid}"}"
  local uid_in_image="${uid_in_image:-}"
  local docker_gid_in_image="${docker_gid_in_image:-}"

  if [[ "${uid_gid}" != "0:0" ]]; then
    local expected_user_name="rootless"
  else
    local expected_user_name="root"
  fi

  local extra_build_args=()
  if [[ -n "${uid_in_image}" ]]; then
    extra_build_args+=("--build-arg=USER_UID=${uid_in_image}")
  fi
  if [[ -n "${docker_gid_in_image}" ]]; then
    extra_build_args+=("--build-arg=DOCKER_GID=${docker_gid_in_image}")
  fi

  docker build -t "${container_name}" -f Dockerfile . "${extra_build_args[@]}"

  docker rm -f "${container_name}"

  local run_options=(--rm --name="${container_name}" --env=FIXDOCKERGID_DEBUG=true)

  # Confirm fixuid is working
  docker run "${run_options[@]}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" "${container_name}" \
    whoami | tee /dev/stderr | grep -q "^${expected_user_name}$"

  if [[ "${expected_user_name}" == "root" || ("${current_user_name}" == "docker" && -z "${uid_in_image}") ]]; then
    docker run "${run_options[@]}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" "${container_name}" \
      groups | tee /dev/stderr | grep -q "^${expected_user_name}$"
  else
    docker run "${run_options[@]}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" "${container_name}" \
      groups | tee /dev/stderr | grep -q -E "^(${expected_user_name} docker)|(docker ${expected_user_name})$"
  fi

  # Confirm fixdockergid is working
  docker run "${run_options[@]}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" "${container_name}" \
    docker version --format '{{.Server.Version}}'

  if [[ "${expected_user_name}" != "root" && "${current_gid}" != "${current_docker_gid}" ]]; then
    # Confirm it doesn't work without fixdockergid
    {
      docker run "${run_options[@]}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" --entrypoint= "${container_name}" \
        docker version --format '{{.Server.Version}}' 2>&1 || true
    } |
      grep 'dial unix /var/run/docker.sock: connect: permission denied'
  fi

  # Test docker exec with --group-add=docker
  docker run "${run_options[@]}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" --group-add=docker -d "${container_name}" sleep infinity
  sleep 1s
  docker exec "${container_name}" docker version --format '{{.Server.Version}}'
  docker rm -f "${container_name}"

  if [[ "${expected_user_name}" != "root" && "${current_gid}" != "${current_docker_gid}" ]]; then
    # Confirm it doesn't work without --group-add
    docker run "${run_options[@]}" -v /var/run/docker.sock:/var/run/docker.sock -u "${uid_gid}" -d "${container_name}" sleep infinity
    sleep 1s
    {
      docker exec "${container_name}" \
        docker version --format '{{.Server.Version}}' 2>&1 || true
    } |
      grep 'dial unix /var/run/docker.sock: connect: permission denied'
    docker rm -f "${container_name}"
  fi
}

readonly current_user_name="$(id -un)"

# Exercise happy paths (i.e. uid and gid are equal to host uid and gid already)
tests

# Exercise non-happy paths
# Ensure UID in image is different from host UID to exercise fixuid
uid_in_image="$((current_uid + 1))"
# Ensure docker GID in image is different from host docker GID to exercise fixdockergid
docker_gid_in_image="$((current_docker_gid - 1))"

tests

unset uid_in_image docker_gid_in_image

# Tests with root
uid_gid="0:0"

tests

unset uid_gid
