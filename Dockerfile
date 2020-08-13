FROM buildpack-deps:focal AS builder

WORKDIR /workspace

RUN apt-get update && \
  apt-get install -y --no-install-recommends software-properties-common && \
  add-apt-repository -y ppa:neurobin/ppa && \
  apt-get update && \
  apt-get install -y shc

COPY fixdockergid.sh .

RUN shc -S -f fixdockergid.sh -o fixdockergid

FROM ubuntu

ARG USER=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USER && \
	useradd --uid $USER_UID --gid $USER_GID -m $USER

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

RUN curl -fsSL https://github.com/boxboat/fixuid/releases/download/v0.5/fixuid-0.5-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - && \
	chown root:root /usr/local/bin/fixuid && \
  chmod 4755 /usr/local/bin/fixuid && \
	mkdir -p /etc/fixuid && \
	printf "user: $USER\ngroup: $USER\n" > /etc/fixuid/config.yml

COPY --from=builder /workspace/fixdockergid /usr/local/bin/
RUN chown root:root /usr/local/bin/fixdockergid && \
  chmod 4755 /usr/local/bin/fixdockergid

COPY entrypoint.sh /
ENTRYPOINT [ "/entrypoint.sh" ]

USER $USER
