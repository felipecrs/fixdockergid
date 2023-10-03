## 0.6.0

- Cleanup and refactor code a little bit, enable all ShellCheck optional checks and fix them.
- Handle a situation where the host user is named `docker` and both the host user's group and the Docker daemon's group are named `docker`.
- Add support for a `FIXDOCKERGID_DEBUG` environment variable to enable debug logs.
- Skip `fixdockergid` and `fixuid` if the container is started as `root`.
- Optimize the code a little bit by relying on `install.sh` to have created the `docker` group.
- Use dind to run tests, so that we can test with different host scenarios.
- Add a check to ensure the container user's group is not named `docker`. This would otherwise cause the `fixuid` to change its GID and potentially break permissions to access the Docker daemon's socket.

## Older versions

Please see the [commits history](https://github.com/felipecrs/fixdockergid/commits/v0.5.0/) for older versions.
