#!/bin/sh

error() {
  echo "$*" >&2
  exit 1
}

set -eu

DOCKER_SOCK='/var/run/docker.sock'
CONFIG_YML='/etc/fixuid/config.yml'

if [ ! -f $CONFIG_YML ]; then
  error "File does not exist: $CONFIG_YML. Did you configure fixuid properly?"
fi

if [ "$(id -u)" != 0 ]; then
  error "Not running as root. Did you configure the suid bit properly?"
fi

if [ -S $DOCKER_SOCK ]; then
  DOCKER_GID="$(stat -c "%g" $DOCKER_SOCK)"
  if [ ! "$(getent group "$DOCKER_GID")" ]; then
    if [ "$(getent group docker)" ]; then
      groupmod -g "$DOCKER_GID" docker
    else
      groupadd -g "$DOCKER_GID" docker
    fi
  fi
  USER="$(awk '/user:/ {print $2}' $CONFIG_YML)"
  usermod -a -G docker "$USER"
fi
