# fixdockergid

This adjust the docker group id on the container to match the docker group id on host, so we can get rid of permission denied errors when we run a docker on docker container with a non-root user.

# How to build

Install the dependencies:

```bash
sudo apt update
sudo apt install -y g++-multilib
```

Build the binary:

```bash
make
```

# How to test

I left a `Dockerfile` in this repository for testing purposes, just run:

```bash
docker build -t fixdockergid .
docker run --rm -it -u "$(id -u):$(id -g)" -v /var/run/docker.sock:/var/run/docker.sock fixdockergid bash
```

Now try something like:

```bash
docker version
```

And you'll see: no permission denied errors anymore.

# How to add in my Dockerfile

```Dockerfile
# Put this in the beginning of your Dockerfile
FROM buildpack-deps:focal AS fixdockergid-builder

WORKDIR /workspace

RUN apt-get update && \
  apt-get install -y --no-install-recommends software-properties-common && \
  add-apt-repository -y ppa:neurobin/ppa && \
  apt-get update && \
  apt-get install -y shc

# Change to some commit hash for safety
ARG FIXDOCKERGID_COMMIT=master
ADD https://raw.githubusercontent.com/felipecassiors/fixdockergid/$FIXDOCKERGID_COMMIT/fixdockergid.sh .

RUN shc -S -f fixdockergid.sh -o fixdockergid

# Your Dockerfile with your custom user goes here, this is an example:
FROM ubuntu

ARG USER=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USER && \
	useradd --uid $USER_UID --gid $USER_GID -m $USER

# Install Docker CLI only
RUN apt-get update && \
	apt-get install --no-install-recommends -y \
	apt-transport-https \
	ca-certificates \
	curl \
	gnupg-agent \
	software-properties-common && \
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
	add-apt-repository \
	"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
	$(lsb_release -cs) \
	stable" && \
	apt-get update && \
	apt-get install --no-install-recommends -y docker-ce-cli

# Install fixuid, fixdockergid depends on it
RUN curl -fsSL https://github.com/boxboat/fixuid/releases/download/v0.5/fixuid-0.5-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - && \
	chown root:root /usr/local/bin/fixuid && \
  chmod 4755 /usr/local/bin/fixuid && \
	mkdir -p /etc/fixuid && \
	printf "user: $USER\ngroup: $USER\n" > /etc/fixuid/config.yml

COPY --from=fixdockergid-builder /workspace/fixdockergid /usr/local/bin/
RUN chown root:root /usr/local/bin/fixdockergid && \
  chmod 4755 /usr/local/bin/fixdockergid

ADD https://raw.githubusercontent.com/felipecassiors/fixdockergid/$FIXDOCKERGID_COMMIT/entrypoint.sh /
RUN chmox +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

USER $USER
```
