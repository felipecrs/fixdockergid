#!/bin/sh

error() {
  echo "$*" >&2
  exit 1
}

set -eu

current_uid="$(id -u)"
if [ "${current_uid}" != 0 ]; then
  error "This script must be run as root."
fi
unset current_uid

if ! command -v curl >/dev/null && ! command -v wget >/dev/null; then
  error "This script needs curl or wget installed."
fi

fixdockergid_dir=/usr/local/share/fixdockergid
mkdir -p "${fixdockergid_dir}"
cd "${fixdockergid_dir}"
_fixdockergid_filename='_fixdockergid'
if [ -f "${_fixdockergid_filename}" ]; then
  # Used when building fixdockergid's Dockerfile
  echo "Using existing ${fixdockergid_dir}/${_fixdockergid_filename}"
else
  if [ -z "${FIXDOCKERGID_COMMIT:-}" ]; then
    error "The FIXDOCKERGID_COMMIT environment variable must be set."
  fi
  echo "Downloading ${_fixdockergid_filename} to ${fixdockergid_dir}/${_fixdockergid_filename}"
  _fixdockergid_url="https://raw.githubusercontent.com/felipecrs/fixdockergid/${FIXDOCKERGID_COMMIT}/_fixdockergid"
  if command -v curl >/dev/null; then
    curl -fsSL -o "${_fixdockergid_filename}" "${_fixdockergid_url}"
  else
    wget -q -O "${_fixdockergid_filename}" "${_fixdockergid_url}"
  fi
fi
chown root:root "${_fixdockergid_filename}"
chmod 4755 "${_fixdockergid_filename}"

## Install fixuid
if ! command -v fixuid >/dev/null; then
  if [ -z "${USERNAME:-}" ]; then
    error "The USERNAME environment variable must be set."
  fi
  fixuid_version='0.6.0'
  echo "Installing fixuid v${fixuid_version}"
  fixuid_url="https://github.com/boxboat/fixuid/releases/download/v${fixuid_version}/fixuid-${fixuid_version}-linux-amd64.tar.gz"
  fixuid_filename='fixuid.tar.gz'
  if command -v curl >/dev/null; then
    curl -fsSL -o "${fixuid_filename}" "${fixuid_url}"
  else
    wget -q -O "${fixuid_filename}" "${fixuid_url}"
  fi
  fixuid_dir='/usr/local/bin'
  tar -C "${fixuid_dir}" -xzf "${fixuid_filename}"
  rm -f "${fixuid_filename}"
  fixuid_binary="${fixuid_dir}/fixuid"
  chown root:root "${fixuid_binary}"
  chmod 4755 "${fixuid_binary}"
  mkdir -p /etc/fixuid
  printf "%s\n" "user: ${USERNAME}" "group: ${USERNAME}" >/etc/fixuid/config.yml
fi

fixdockergid_binary='/usr/local/bin/fixdockergid'
echo "Installing fixdockergid to ${fixdockergid_binary}"
tee "${fixdockergid_binary}" >/dev/null \
  <<EOF
#!/bin/sh

set -eu

if [ "\${FIXDOCKERGID_DEBUG:-}" = "true" ]; then
  set -x
fi

# Skip if running as root
current_uid="\$(id -u)"
if [ "\${current_uid}" = 0 ]; then
  exec "\$@"
fi
unset current_uid

'${fixdockergid_dir}/${_fixdockergid_filename}'

exec fixuid -q -- "\$@"
EOF
chmod +x "${fixdockergid_binary}"

echo "Ensuring docker group exists"
if ! getent group docker >/dev/null; then
  groupadd -r docker
fi

echo "Ensuring ${USERNAME} is part of docker group"
usermod -a -G docker "${USERNAME}"

echo "fixdockergid installation done."
