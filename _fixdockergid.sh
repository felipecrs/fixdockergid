#!/bin/sh

set -eu

if [ "${FIXDOCKERGID_DEBUG:-}" = "true" ]; then
  set -x
fi

error() {
  echo "$*" >&2
  exit 1
}

fixuid_config='/etc/fixuid/config.yml'

if [ ! -f "${fixuid_config}" ]; then
  error "File does not exist: ${fixuid_config}. Did you configure fixuid properly?"
fi

current_uid="$(id -u)"
if [ "${current_uid}" != 0 ]; then
  error "Not running as root. Did you configure the suid bit properly?"
fi
unset current_uid

docker_sock='/var/run/docker.sock'
if [ -S "${docker_sock}" ]; then
  docker_gid="$(stat -c "%g" "${docker_sock}")"

  fixuid_group_name="$(awk '/group:/ {print $2}' "${fixuid_config}")"
  if [ "${fixuid_group_name}" = "docker" ]; then
    error "The fixuid group name cannot be 'docker'."
  fi

  if getent group "${docker_gid}" >/dev/null; then
    # A group with the docker GID already exists

    # Check if it is named docker
    docker_gid_group_name="$(getent group "${docker_gid}" | cut -d: -f1)"
    if [ "${docker_gid_group_name}" != "docker" ]; then
      # In this case we make the group named docker be an alias of such group.
      groupmod -o -g "${docker_gid}" docker
    fi
    unset docker_gid_group_name
  else
    # There is no group with docker GID, so we fix the group named docker to
    # have the proper docker GID.
    groupmod -g "${docker_gid}" docker
  fi

  fixuid_user_name="$(awk '/user:/ {print $2}' "${fixuid_config}")"
  usermod -a -G docker "${fixuid_user_name}"
fi
