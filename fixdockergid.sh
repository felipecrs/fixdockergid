#!/bin/sh

set -eu

DOCKER_SOCK='/var/run/docker.sock'
CONFIG_YML='/etc/fixuid/config.yml'

if [ ! -f $CONFIG_YML ]; then
  echo "File does not exist: $CONFIG_YML. Did you configured fixuid properly?" >&2
  exit 1
fi

if [ "$(id -u)" != 0 ]; then
  echo "Not running as root. Did you configured the suid bit properly?" >&2
  exit 1
fi

if [ ! -S $DOCKER_SOCK ]; then
  echo "Socket does not exist: $DOCKER_SOCK.
  Did you mounted the docker socket with '-v $DOCKER_SOCK:$DOCKER_SOCK'?" >&2
  exit 1
fi

USER="$(awk '/user:/ {print $2}' $CONFIG_YML)"

DOCKER_GID="$(stat -c "%g" $DOCKER_SOCK)"
if [ ! "$(getent group "$DOCKER_GID")" ]; then
  groupadd -g "$DOCKER_GID" docker
fi
DOCKER_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1)
usermod -a -G "$DOCKER_GROUP" "$USER"

UID=$1
shift
GID=$1
shift

exec setpriv "--reuid=$UID" "--regid=$GID" --init-groups fixuid "$@"
