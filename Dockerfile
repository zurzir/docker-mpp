ARG BASE_IMAGE=ubuntu:noble

FROM ${BASE_IMAGE} AS mppbocarepo
RUN apt-get -y update && apt-get -y install git ca-certificates
WORKDIR /
RUN git clone https://github.com/KGMats/boca.git
WORKDIR /boca
RUN git checkout master

######################

FROM ${BASE_IMAGE} AS mppbocabase
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    TZ=America/Sao_Paulo \
    LANG=en_US.UTF-8 \
    LC_ALL=C.UTF-8 \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data

RUN apt-get -y update \
    && apt-get -y dist-upgrade \
    && apt-get -y install --no-install-recommends \
        # Miscellaneous
        locales \
        tzdata \
        # Package: boca-common
        # https://github.com/cassiopc/boca/blob/master/debian/control
        # Pre-Depends:
        debconf \
        ca-certificates \
        makepasswd \
        sharutils \
        # Depends:
        libany-uri-escape-perl \
        openssl \
        php-cli \
        php-gd \
        php-pgsql \
        php-xml \
        php-zip \
        postgresql-client \
        wget \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Copy BOCA repository from mppbocarepo stage
COPY --from=mppbocarepo --chown="${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" /boca/doc /var/www/boca/doc
COPY --from=mppbocarepo --chown="${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" /boca/src /var/www/boca/src
COPY --from=mppbocarepo --chown="${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" /boca/tools /var/www/boca/tools

# Copy local config files
COPY --chown="${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" boca/src/private/conf.php /var/www/boca/src/private/
COPY --chown="${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" boca/src/private/createdb.php /var/www/boca/src/private/

WORKDIR /var/www/boca
RUN \
    # install-bocacommon
    # https://github.com/cassiopc/boca/blob/master/Makefile
    mkdir -p /usr/sbin /etc/cron.d /var/www/boca/ \
    && install tools/boca-fixssh /usr/sbin/ \
    && install tools/cron-boca-fixssh /etc/cron.d/ \
    && chmod 700 /usr/sbin/boca-fixssh \
    && cp tools/boca.conf /etc/ \
    # boca-common.postinst
    # https://github.com/cassiopc/boca/blob/master/debian/boca-common.postinst
    && install tools/boca-config-dbhost.sh /usr/sbin/boca-config-dbhost \
    && chmod 700 /usr/sbin/boca-config-dbhost \
    && chmod 600 /var/www/boca/src/private/conf.php

######################

FROM mppbocabase AS mppbocaweb
ENV APACHE_DIR=/etc/apache2 \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_DIR=/var/run/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2 \
    APACHE_LOG_DIR=/var/log/apache2

RUN apt-get -y update \
    && apt-get -y install --no-install-recommends \
        # Package: boca-web
        # https://github.com/cassiopc/boca/blob/master/debian/control
        # Depends:
        apache2 \
        libapache2-mod-php \
        php \
        php-fpm \
        python3-matplotlib

RUN mkdir -p $APACHE_LOCK_DIR $APACHE_LOG_DIR $APACHE_RUN_DIR \
    && echo "ServerName localhost" >> $APACHE_DIR/apache2.conf \
    && ln -sf /proc/self/fd/1 $APACHE_LOG_DIR/access.log \
    && ln -sf /proc/self/fd/1 $APACHE_LOG_DIR/error.log \
    && chown -R "${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" "$APACHE_LOCK_DIR" "$APACHE_LOG_DIR" "$APACHE_RUN_DIR"

WORKDIR /var/www/boca
RUN \
    # install-bocaweb
    # https://github.com/cassiopc/boca/blob/master/Makefile
    mkdir -p $APACHE_DIR/sites-available/ \
    && cp tools/000-boca.conf $APACHE_DIR/sites-available/000-boca.conf \
    && mkdir -p /usr/sbin/ \
    && install tools/dump.sh /usr/sbin/boca-dump \
    && chmod 700 /usr/sbin/boca-dump \
    && chown -R "${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" /var/www/boca \
    && chmod -R go-rwx /var/www/boca/src/private \
    # boca-web.postinst
    # https://github.com/cassiopc/boca/blob/master/debian/boca-web.postinst
    && a2enmod ssl socache_shmcb proxy_fcgi setenvif \
    && mkdir -p $APACHE_DIR/sites-enabled \
    && cp tools/000-boca.conf $APACHE_DIR/sites-enabled/000-boca.conf \
    && apache2ctl configtest \
    && touch /etc/php/8.3/apache2/conf.d/99-boca-limits.ini \
    && touch /etc/php/8.3/cli/conf.d/99-boca-limits.ini \
    && chown "${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" /etc/php/8.3/apache2/conf.d/99-boca-limits.ini /etc/php/8.3/cli/conf.d/99-boca-limits.ini

COPY --chmod=755 --chown="${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" web-init.sh /

USER ${APACHE_RUN_USER}
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/boca/ || exit 1
EXPOSE 80
ENTRYPOINT ["/web-init.sh"]


######################

FROM mppbocabase AS mppbocajail

RUN apt-get -y update \
    && apt-get -y install --no-install-recommends \
        # Package: boca-autojudge
        # https://github.com/cassiopc/boca/blob/master/debian/control
        # Depends:
        build-essential \
        debootstrap \
        makepasswd \
        quotatool \
        quota \
        file \
        lsb-release \
        schroot

# https://bugs.launchpad.net/ubuntu/+source/ca-certificates-java/+bug/2019908
COPY boca/tools/boca-createjail /var/www/boca/tools/
COPY boca/tools/safeexec.c /var/www/boca/tools/

WORKDIR /var/www/boca
RUN \
    # install-bocaautojudge
    # https://github.com/cassiopc/boca/blob/master/Makefile
    mkdir -p /usr/sbin/ /usr/bin/ /etc/ \
    && gcc tools/safeexec.c -o tools/safeexec \
    && install tools/safeexec /usr/bin/safeexec \
    && install tools/boca-createjail /usr/sbin/boca-createjail \
    && install tools/boca-autojudge.sh /usr/sbin/boca-autojudge \
    && chmod 4555 /usr/bin/safeexec \
    && chmod 700 /usr/sbin/boca-createjail \
    && chmod 700 /usr/sbin/boca-autojudge
    # boca-autojudge.postinst
    # https://github.com/cassiopc/boca/blob/master/debian/boca-autojudge.postinst
    # Done before
    # && chmod 4555 /usr/bin/safeexec \
    # && chmod 700 /usr/sbin/boca-createjail \
    # && chmod 700 /usr/sbin/boca-autojudge

RUN boca-createjail

COPY --chmod=755 jail-init.sh /

# Add HEALTHCHECK instruction to the container image
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
    CMD ps ax | grep -v grep | grep php | grep autojudging.php > /dev/null || exit 1

# Use exec format to run program directly as pid 1
# https://www.padok.fr/en/blog/docker-processes-container
ENTRYPOINT ["/jail-init.sh"]
