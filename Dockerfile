FROM buildpack-deps:focal AS build

WORKDIR /workspace

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 768A7859711D60A876466300137880E4BA5CB7FD 2>/dev/null \
  && echo "deb http://ppa.launchpad.net/neurobin/ppa/ubuntu focal main" | tee /etc/apt/sources.list.d/shc.list \
  && apt-get update \
  && apt-get install -y shc \
  # Clean up \
  && rm -rf /var/lib/apt/lists/*

COPY _fixdockergid.sh .

RUN shc -S -r -f _fixdockergid.sh -o _fixdockergid


FROM scratch AS bin

COPY --from=build /workspace/_fixdockergid /


FROM ubuntu

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
  # Clean up \
  && rm -rf /var/lib/apt/lists/*

COPY --from=bin / /usr/local/share/fixdockergid/
COPY install.sh /tmp/
RUN /tmp/install.sh \
  && rm -f /tmp/install.sh

ENTRYPOINT [ "fixdockergid" ]

USER ${USERNAME}
