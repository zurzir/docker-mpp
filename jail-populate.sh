#!/bin/bash
set -e

cat <<EOF >/home/bocajail/populate.sh
#!/bin/bash

echo "LC_ALL=en_US.UTF-8" > /etc/default/locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
/usr/sbin/locale-gen
/usr/sbin/update-locale

apt-get -y update
apt-get -y install software-properties-common
add-apt-repository -y ppa:icpc-latam/maratona-linux
apt-get -y update
apt-get -y install maratona-linguagens file --no-install-recommends --allow-unauthenticated
apt-get -y clean

EOF

cp -a /usr/bin/safeexec /bocajail/usr/bin/
cp -f /etc/apt/sources.list.d/* /home/bocajail/etc/apt/sources.list.d/
chmod 755 /home/bocajail/populate.sh

mount -t proc proc /home/bocajail/proc
chroot /home/bocajail /populate.sh
umount /proc
