FROM ubuntu

ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

# Install Docker CLI
RUN apt-get update \
  && apt-get install -y apt-transport-https ca-certificates curl gnupg2 lsb-release \
  && curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | apt-key add - 2>/dev/null \
  && echo "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y docker-ce-cli \
  # Clean up
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

COPY install.sh _fixdockergid /usr/local/share/fixdockergid/
RUN cd /usr/local/share/fixdockergid/ \
  && chmod +x install.sh \
  && ./install.sh \
  && rm -f /tmp/install.sh

ENTRYPOINT [ "fixdockergid" ]

USER ${USERNAME}
