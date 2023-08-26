#!/bin/sh

error() {
  echo "$*" >&2
  exit 1
}

set -eu

if [ "$(id -u)" != 0 ]; then
  error "This script must be run as root."
fi

if [ ! "$(command -v curl)" ] && [ ! "$(command -v wget)" ]; then
  error "This script needs curl or wget installed."
fi

fixdockergid_dir=/usr/local/share/fixdockergid
mkdir -p $fixdockergid_dir
cd $fixdockergid_dir
_fixdockergid_filename='_fixdockergid'
if [ ! -f "$_fixdockergid_filename" ]; then
  if [ -z "${FIXDOCKERGID_COMMIT+x}" ]; then
    error "The FIXDOCKERGID_COMMIT environment variable must be set."
  fi
  echo "Downloading $_fixdockergid_filename to $fixdockergid_dir/$_fixdockergid_filename"
  _fixdockergid_url="https://raw.githubusercontent.com/felipecrs/fixdockergid/$FIXDOCKERGID_COMMIT/_fixdockergid"
  if [ "$(command -v curl)" ]; then
    curl -fsSL -o $_fixdockergid_filename "$_fixdockergid_url"
  else
    wget -q -O $_fixdockergid_filename "$_fixdockergid_url"
  fi
else
  echo "Using existing $fixdockergid_dir/$_fixdockergid_filename"
fi
chown root:root $_fixdockergid_filename
chmod 4755 $_fixdockergid_filename

## Install fixuid
if [ ! "$(command -v fixuid)" ]; then
  if [ -z "${USERNAME+x}" ]; then
    error "The USERNAME environment variable must be set."
  fi
  fixuid_version='0.6.0'
  echo "Installing fixuid v$fixuid_version"
  fixuid_url="https://github.com/boxboat/fixuid/releases/download/v$fixuid_version/fixuid-$fixuid_version-linux-amd64.tar.gz"
  fixuid_filename='fixuid.tar.gz'
  if [ "$(command -v curl)" ]; then
    curl -fsSL -o $fixuid_filename $fixuid_url
  else
    wget -q -O $fixuid_filename $fixuid_url
  fi
  fixuid_dir='/usr/local/bin'
  tar -C $fixuid_dir -xzf $fixuid_filename
  rm -f $fixuid_filename
  fixuid_binary="$fixuid_dir/fixuid"
  chown root:root $fixuid_binary
  chmod 4755 $fixuid_binary
  mkdir -p /etc/fixuid
  printf "%s\n" "user: $USERNAME" "group: $USERNAME" >/etc/fixuid/config.yml
fi

fixdockergid_binary='/usr/local/bin/fixdockergid'
echo "Installing fixdockergid to $fixdockergid_binary"
tee $fixdockergid_binary >/dev/null \
  <<EOF
#!/bin/sh

set -eu

'$fixdockergid_dir/$_fixdockergid_filename'

exec fixuid -q -- "\$@"
EOF
chmod +x $fixdockergid_binary

echo "Ensuring docker group exists"
if [ ! "$(getent group docker)" ]; then
  groupadd --system docker
fi

echo "Ensuring $USERNAME is part of docker group"
usermod -a -G docker "$USERNAME"

echo "fixdockergid installation done."
