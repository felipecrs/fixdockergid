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

if ! [ "$1" -eq "$1" ] 2>/dev/null; then
  error "First argument does not seem to be an UID. Usage: $0 \$(id -u) \$(id -g) [...]"
fi

UID=$1; shift

if ! [ "$1" -eq "$1" ] 2>/dev/null; then
  error "Second argument does not seem to be an GID. Usage: $0 \$(id -u) \$(id -g) [...]"
fi

GID=$1; shift

if [ -S $DOCKER_SOCK ]; then
  DOCKER_GID="$(stat -c "%g" $DOCKER_SOCK)"
  if [ ! "$(getent group "$DOCKER_GID")" ]; then
    if [ "$(getent group docker)" ]; then
      groupmod -g "$DOCKER_GID" docker
    else
      groupadd -g "$DOCKER_GID" docker
    fi
  fi
  DOCKER_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1)
  USER="$(awk '/user:/ {print $2}' $CONFIG_YML)"
  usermod -a -G "$DOCKER_GROUP" "$USER"
fi

exec setpriv "--reuid=$UID" "--regid=$GID" --init-groups -- "$@"
