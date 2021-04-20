FROM ubuntu

# The fixdockergid installation must be run as root, so you must set USER root
# in case your Dockerfile switched to another user before.
USER root

# Create non-root user
ARG USERNAME="rootless"
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

# Install Docker CLI
RUN apt-get update \
  && apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release \
  && curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | apt-key add - 2>/dev/null \
  && echo "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y docker-ce-cli \
  # Create docker group
  && groupadd docker \
  && usermod -aG docker $USERNAME \
  # Clean up \
  && rm -rf /var/lib/apt/lists/*

# Replace with a commit hash
ARG FIXDOCKERGID_COMMIT='HEAD'
# You must also set ARG USERNAME in case your Dockerfile does not have it already
RUN curl -fsSL https://raw.githubusercontent.com/felipecrs/fixdockergid/${FIXDOCKERGID_COMMIT}/install.sh | sh -

ENTRYPOINT [ "fixdockergid" ]

USER ${USERNAME}
