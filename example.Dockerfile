# Put this in the beginning of your Dockerfile
# Change to some commit hash for safety
ARG FIXDOCKERGID_COMMIT=master

FROM buildpack-deps:focal AS fixdockergid-builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends software-properties-common \
  && add-apt-repository -y ppa:neurobin/ppa \
  && apt-get update \
  && apt-get install -y shc

WORKDIR /workspace

ARG FIXDOCKERGID_COMMIT
RUN curl -fsSLO https://raw.githubusercontent.com/felipecassiors/fixdockergid/$FIXDOCKERGID_COMMIT/fixdockergid.sh \
  && shc -S -r -f fixdockergid.sh -o fixdockergid

# Your Dockerfile with your custom user goes here, this is an example:
FROM ubuntu

ARG USER=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USER \
  && useradd --uid $USER_UID --gid $USER_GID -m $USER

# Install Docker CLI only
RUN apt-get update \
  && apt-get install -y apt-transport-https ca-certificates curl gnupg2 lsb-release \
  && curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | apt-key add - 2>/dev/null \
  && echo "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y docker-ce-cli

# Install fixuid, fixdockergid depends on it
RUN curl -fsSL https://github.com/boxboat/fixuid/releases/download/v0.5/fixuid-0.5-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - \
  && chown root:root /usr/local/bin/fixuid \
  && chmod 4755 /usr/local/bin/fixuid \
  && mkdir -p /etc/fixuid \
  && printf "user: $USER\ngroup: $USER\n" > /etc/fixuid/config.yml

COPY --from=fixdockergid-builder /workspace/fixdockergid /usr/local/bin/
ARG FIXDOCKERGID_COMMIT
RUN chown root:root /usr/local/bin/fixdockergid \
  && chmod 4755 /usr/local/bin/fixdockergid \
  && curl -fsSLO https://raw.githubusercontent.com/felipecassiors/fixdockergid/$FIXDOCKERGID_COMMIT/entrypoint.sh \
  && chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]

USER $USER
