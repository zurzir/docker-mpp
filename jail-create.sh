#!/bin/bash
set -e
useradd -m -s /bin/bash -d /home/bocajail -g users bocajail
mkdir -p /var/lib/AccountsService/users

cat <<EOF >/var/lib/AccountsService/users/bocajail
[User]
SystemAccount=true
EOF

# this does not work in container
# setquota -u bocajail 0 500000 0 10000 -a

mkdir -p /home/bocajail/tmp
chmod 1777 /home/bocajail/tmp
ln -s /home/bocajail /bocajail

cat <<FIM >/etc/schroot/chroot.d/bocajail.conf
[bocajail]
description=Jail
directory=/home/bocajail
root-users=root
type=directory
users=bocajail,nobody,root
FIM

. /etc/lsb-release # criar var DISTRIB_CODENAME
debootstrap $DISTRIB_CODENAME /home/bocajail
schroot -l | grep -q bocajail # teste se funciona
