#!/bin/bash
set -e

cat <<EOF >/home/bocajail/java.sh
#!/bin/bash
# instala de novo todos os pacotes de maratona-linguagens, para corrigir errados
# pacotes que já foram instalados com sucesso no build vão virar noop
apt-get -y install build-essential debconf openjdk-21-jdk gdb python3 pypy3 python-is-python3 pyflakes3 pylint python3-setuptools unzip wget valgrind
echo /usr/lib/jvm/java-21-openjdk-amd64/lib > /etc/ld.so.conf.d/java.conf
ldconfig
EOF

chmod 755 /home/bocajail/java.sh

mount -t proc proc /home/bocajail/proc
chroot /home/bocajail /java.sh
umount /home/bocajail/proc
