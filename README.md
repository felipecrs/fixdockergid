# fixdockergid

This adjusts the docker group id on the container to match the docker group id on host, so we can get rid of permission denied errors when we try to access the docker host from a container as a non-root user.

The `fixdockergid` depends on [`fixuid`](https://github.com/boxboat/fixuid) to work, and [I hope its functionalities gets incorporated in it](https://github.com/boxboat/fixuid/issues/29) in the future.

Advantages:
  - No need to start the container as `root`.
  - Does not require `sudo` to perform its operations.

# How do I test?

I left a `Dockerfile` in this repository for testing purposes, just run:

```bash
docker build -t fixdockergid .
docker run --rm -it -u "$(id -u):$(id -g)" -v /var/run/docker.sock:/var/run/docker.sock fixdockergid docker version
```

And note: you're able to access the docker host from the container as a non-root user. The container's user matches the user on host (thanks to `fixuid`), and the user on the container is part of the a group which matches the docker group on host.

# How do I add this to my Dockerfile?

This was only tested on `ubuntu` containers. See: [example.Dockerfile](./example.Dockerfile).

```Dockerfile
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
```
