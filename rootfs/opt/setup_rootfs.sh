#!/bin/bash
set -euo pipefail
# the whole thing was basically stolen from shimboot

HOSTNAME="appleboot"
PACKAGES="task-xfce-desktop dbus-x11"
DEBIAN_RELEASE="bookworm"
USERNAME="user"
ROOT_PASS="root"
USER_PASS="user"
ARCH="amd64"

# thanks vk6
custom_repo="https://shimboot.ading.dev/debian"
custom_repo_domain="shimboot.ading.dev"
sources_entry="deb [trusted=yes arch=$ARCH] ${custom_repo} ${DEBIAN_RELEASE} main"

export DEBIAN_FRONTEND="noninteractive"

# add vk6 repos
echo -e "${sources_entry}\n$(cat /etc/apt/sources.list)" > /etc/apt/sources.list
tee -a /etc/apt/preferences << END
Package: *
Pin: origin ${custom_repo_domain}
Pin-Priority: 1001
END

if [ "$ARCH" = "amd64" ]; then
  dpkg --add-architecture i386
fi

# install certs to prevent apt ssl errors
apt-get install -y ca-certificates
apt-get update

# install patched systemd
apt-get upgrade -y --allow-downgrades
installed_systemd="$(dpkg-query -W -f='${binary:Package}\n' | grep "systemd")"
apt-get clean
apt-get install -y --reinstall --allow-downgrades $installed_systemd

# enable kill frecon service
systemctl enable kill-frecon.service

apt-get install -y cloud-utils zram-tools sudo command-not-found bash-completion libfuse2 libfuse3-*

echo "ALGO=lzo" >> /etc/default/zramswap
echo "PERCENT=100" >> /etc/default/zramswap

if which apt-file >/dev/null; then
    apt-file update
else #old versions of command-not-found did not use apt-file
    apt-get update
fi

echo "$HOSTNAME" > /etc/hostname
tee -a /etc/hosts << END
127.0.0.1 localhost
127.0.1.1 $HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
END

apt-get install -y $PACKAGES

# the appleboot loader already disables selinux, do we still need to disable it here?
echo "SELINUX=disabled" >> /etc/selinux/config

useradd -m -s /bin/bash -G sudo $USERNAME

# set passwords for root and user
yes "$ROOT_PASS" | passwd "root" || true
yes "$USER_PASS" | passwd $USERNAME || true

# clean the apt caches
apt-get clean

exit 0