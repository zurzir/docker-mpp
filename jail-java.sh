#!/bin/bash
set -e

cat <<EOF >/home/bocajail/java.sh
#!/bin/bash
apt-get -y install default-jdk
# apt-get -y install maratona-linguagens
echo /usr/lib/jvm/java-21-openjdk-amd64/lib > /etc/ld.so.conf.d/java.conf
ldconfig
EOF

chmod 755 /home/bocajail/java.sh

mount -t proc proc /home/bocajail/proc
chroot /home/bocajail /java.sh
umount /home/bocajail/proc
