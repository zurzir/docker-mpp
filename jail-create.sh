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

cat <<EOF >/home/bocajail/populate.sh
#!/bin/bash

echo "LC_ALL=en_US.UTF-8" > /etc/default/locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
/usr/sbin/locale-gen
/usr/sbin/update-locale

# apt-get -y update
# apt-get -y install software-properties-common
# add-apt-repository -y ppa:icpc-latam/maratona-linux
# apt-get -y update
# apt-get -y install maratona-linguagens file --no-install-recommends --allow-unauthenticated
# apt-get -y clean

apt-get -y update
apt-get -y install build-essential python3 pypy3 python-is-python3
apt-get -y clean

EOF

cp -a /usr/bin/safeexec /bocajail/usr/bin/
cp -f /etc/apt/sources.list.d/* /home/bocajail/etc/apt/sources.list.d/
chmod 755 /home/bocajail/populate.sh

chroot /home/bocajail /populate.sh
