FROM ubuntu

# The fixdockergid installation must be run as root, so you must set USER root
# in case your Dockerfile switched to another user before.
USER root

# Create non-root user
ARG USERNAME="rootless"
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN \
  # Create non-root user \
  groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
  # Install Docker CLI \
  && apt-get update \
  && apt-get install -y apt-transport-https ca-certificates curl gnupg \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends docker-ce-cli \
  # Clean up \
  && rm -rf /var/lib/apt/lists/*

# Replace with a git tag
ARG FIXDOCKERGID_VERSION="0.7.2"
# You must also set ARG USERNAME
RUN curl -fsSL "https://github.com/felipecrs/fixdockergid/raw/v${FIXDOCKERGID_VERSION}/install.sh" | sh -

ENTRYPOINT [ "fixdockergid" ]

USER ${USERNAME}
