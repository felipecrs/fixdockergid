# syntax=docker/dockerfile:1.2

# Compiles _fixdockergid.sh with the suid bit set
FROM buildpack-deps:focal AS build

WORKDIR /workspace

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 768A7859711D60A876466300137880E4BA5CB7FD 2>/dev/null \
  && echo "deb http://ppa.launchpad.net/neurobin/ppa/ubuntu focal main" | tee /etc/apt/sources.list.d/shc.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends shc \
  # Clean up \
  && rm -rf /var/lib/apt/lists/*

COPY _fixdockergid.sh .

RUN shc -S -r -f _fixdockergid.sh -o _fixdockergid


# Used by build.sh
FROM scratch AS bin

COPY --from=build /workspace/_fixdockergid /


# Main image
FROM ubuntu:focal AS main

# Create non-root user
ARG USERNAME="rootless"
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

# Install Docker CLI
RUN apt-get update \
  && apt-get install -y apt-transport-https ca-certificates curl gnupg \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 2>/dev/null \
  && echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" | tee /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends docker-ce-cli \
  # Clean up \
  && rm -rf /var/lib/apt/lists/*

COPY --from=bin / /usr/local/share/fixdockergid/
RUN --mount=source=install.sh,target=/tmp/install.sh \
  /tmp/install.sh

ENTRYPOINT [ "fixdockergid" ]

USER ${USERNAME}


# Used by test.sh
FROM main AS test

USER root

# Change docker group id (useful during testing)
ARG DOCKER_GID
RUN if [ -n "${DOCKER_GID}" ]; then groupmod -g "${DOCKER_GID}" docker; fi

# Create a group for host docker gid, to detect if fixdocker will handle it
ARG HOST_DOCKER_GID
RUN if [ -n "${HOST_DOCKER_GID}" ]; then groupadd -g "${HOST_DOCKER_GID}" hostdocker; fi

USER rootless


# Set default target
FROM main
