#!/bin/bash

set -eux

DOCKER_SOCK="/var/run/docker.sock"

# If docker.sock isn't mounted or we're running as root, don't do nothing
if ls $DOCKER_SOCK >/dev/null 2>&1 && [ $(id -u) != 0 ]; then
	DOCKER_GID="$(stat -c "%g" $DOCKER_SOCK)"
	if [ ! $(getent group $DOCKER_GID) ]; then
		addgroup -g $DOCKER_GID docker
	fi
	DOCKER_GROUP=$(getent group $DOCKER_GID | cut -d: -f1)
	addgroup $USER $DOCKER_GROUP
fi
