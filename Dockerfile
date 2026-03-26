ARG BASE_IMAGE="buildpack-deps:noble"
ARG USERNAME="rootless"

FROM ${BASE_IMAGE}-curl AS base


# Compiles _fixdockergid.sh with the suid bit set
FROM ${BASE_IMAGE} AS build

RUN \
  apt-get update \
  && apt-get install -y --no-install-recommends shc \
  # Clean up \
  && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,source=_fixdockergid.sh,target=/_fixdockergid.sh \
  CFLAGS="-static" shc -S -r -f /_fixdockergid.sh -o /_fixdockergid


# Used by build.sh
FROM scratch AS dist

ARG TARGETARCH
COPY --from=build /_fixdockergid /dist/_fixdockergid.linux_${TARGETARCH}


# Contains non-root user and docker-cli
FROM base AS docker-cli

# Create non-root user
ARG USERNAME
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN \
  # Ubuntu 24.04 image comes with this user by default \
  if getent passwd ubuntu >/dev/null; then \
      userdel -r ubuntu; \
  fi \
  # Create non-root user \
  && groupadd --gid "$USER_GID" "$USERNAME" \
  && useradd --uid "$USER_UID" --gid "$USER_GID" -m "$USERNAME"

# Install Docker CLI
RUN \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod 0644 /etc/apt/keyrings/docker.asc \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends docker-ce-cli \
  # Clean up \
  && rm -rf /var/lib/apt/lists/*


# Main image
FROM docker-cli AS main

ARG USERNAME
COPY --from=build /_fixdockergid /usr/local/share/fixdockergid/
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

ARG USERNAME
USER ${USERNAME}


FROM docker-cli AS dind

# Install Docker
ARG USERNAME
RUN \
  apt-get update \
  && apt-get install -y --no-install-recommends docker-ce containerd.io docker-buildx-plugin sudo \
  # Clean up \
  && rm -rf /var/lib/apt/lists/* \
  # Add user to sudoers \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${USERNAME}" \
  # Add user to docker group \
  && usermod -aG docker "${USERNAME}"

VOLUME ["/var/lib/docker"]

CMD ["sudo", "dockerd"]

USER ${USERNAME}


# Set default target
FROM main
