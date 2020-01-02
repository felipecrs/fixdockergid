FROM alpine

RUN addgroup -g 1000 user && \
    adduser -u 1000 -G user -h /home/user -s /bin/sh -D user

RUN apk --update add \
  docker \
  && rm -rf /var/cache/apk/*

RUN USER=user && \
    GROUP=user && \
    wget -q -O- https://github.com/boxboat/fixuid/releases/download/v0.4/fixuid-0.4-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: $USER\ngroup: $GROUP\n" > /etc/fixuid/config.yml

COPY fixdockergid /usr/local/bin/

RUN chmod 4755 /usr/local/bin/fixdockergid

USER user:user

COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT [ "entrypoint.sh" ]
