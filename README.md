# fixdockergid

This adjusts the docker group id on the container to match the docker group id on host, so we can get rid of permission denied errors when we try to access the docker host from a container as a non-root user.

The `fixdockergid` depends on [`fixuid`](https://github.com/boxboat/fixuid) to work, and [I hope its functionalities gets incorporated in it](https://github.com/boxboat/fixuid/issues/29) in the future.

Advantages:

- No need to start the container as `root`.
- Does not require `sudo` to perform its operations.
- Convenient install script.

## Try it out

I built an image for testing using the [`Dockerfile`](./Dockerfile) and pushed to [DockerHub as felipecassiors/fixdockergid](https://hub.docker.com/r/felipecassiors/fixdockergid) so you can try it out, just run:

```bash
docker run --rm -u "$(id -u):$(id -g)" -v /var/run/docker.sock:/var/run/docker.sock felipecassiors/fixdockergid docker run hello-world
```

And note: you're able to access the docker host from the container as a non-root user. The container's user matches the user on host (thanks to `fixuid`), and the user on the container is part of the a group which matches the docker group on host.

## Install

Just add the following snippet to your `Dockerfile`. This was only tested on `ubuntu` containers. See: [example.Dockerfile](./example.Dockerfile).

```Dockerfile
# You must set USER root in case your Dockerfile switched to another user before
# Replace with a commit hash
ARG FIXDOCKERGID_COMMIT='master'
# You must also set ARG USERNAME in case your Dockerfile does not have it already
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/felipecassiors/fixdockergid/$FIXDOCKERGID_COMMIT/install.sh)"

ENTRYPOINT [ "fixdockergid" ]

USER ${USERNAME}
```
