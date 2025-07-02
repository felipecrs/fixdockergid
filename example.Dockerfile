FROM ubuntu:24.04

# The fixdockergid installation must be run as root, so you must set USER root
# in case your Dockerfile switched to another user before.
USER root

# Ubuntu 24.04 image comes with this user by default
ARG USERNAME="ubuntu"

# Install Docker CLI
RUN \
  apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod 0644 /etc/apt/keyrings/docker.asc \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends docker-ce-cli \
  # Clean up \
  && rm -rf /var/lib/apt/lists/*

# Replace with a git tag
ARG FIXDOCKERGID_VERSION="0.7.3"
# You must also set ARG USERNAME
RUN curl -fsSL "https://github.com/felipecrs/fixdockergid/raw/v${FIXDOCKERGID_VERSION}/install.sh" | sh -

ENTRYPOINT [ "fixdockergid" ]

USER ${USERNAME}
