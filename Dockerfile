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


FROM buildpack-deps:focal-curl

# Create non-root user
ARG USERNAME="rootless"
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

# Install Docker CLI
RUN curl -fsSL \
  https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce-cli_20.10.6~3-0~ubuntu-focal_amd64.deb \
  -o /tmp/docker.deb \
  && apt-get install -y --no-install-recommends /tmp/docker.deb \
  && rm -f /tmp/docker.deb \
  # Create docker group \
  && groupadd docker \
  && usermod -aG docker $USERNAME \
  && rm -rf /var/lib/apt/lists/*

COPY --from=bin / /usr/local/share/fixdockergid/
COPY install.sh /tmp/
RUN /tmp/install.sh \
  && rm -f /tmp/install.sh

ENTRYPOINT [ "fixdockergid" ]

USER ${USERNAME}
