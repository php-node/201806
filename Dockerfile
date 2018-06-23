FROM php:apache

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
    && apt-get update -y && apt-get upgrade -y; \
    apt-get install -y wget zlib1g-dev nano; \
    cd ~ \
    && wget https://nih.at/libzip/libzip-1.2.0.tar.gz \ 
    && tar -zxf libzip-1.2.0.tar.gz \
    && cd libzip-1.2.0 \
    && ./configure && make && make install; \
    \
    apt-get install -y libzip-dev; \
    \
    ln -s /usr/local/lib/libzip/include/zipconf.h /usr/local/include; \
    \
    wget http://pecl.php.net/get/zip-1.15.3.tgz \
    && tar zxf zip-1.15.3.tgz && cd zip-1.15.3 \
    && phpize && ./configure --with-php-config=/usr/local/bin/php-config \
    && make && make install; \
    \
    ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load; \
    \
    cd ~; \
    wget https://github.com/phpredis/phpredis/archive/4.0.2.tar.gz; \
    tar -zxf 4.0.2.tar.gz; \
    cd phpredis-4.0.2; \
    phpize && ./configure --with-php-config=/usr/local/bin/php-config; \
    make && make install; \
    \
    docker-php-ext-install mysqli pdo pdo_mysql; \
    { \
    echo "extension=redis.so"; \
    # echo "extension=/root/libzip-1.2.0/zip-1.15.2/modules/zip.so"; \
    echo "extension=zip.so"; \
    echo "zlib.output_compression = On"; \
    } >> /usr/local/etc/php/php.ini

RUN cd ~ && curl -sS https://getcomposer.org/installer | php \
    && cp composer.phar /usr/local/bin/composer; \
    composer config -g repo.packagist composer https://packagist.phpcomposer.com; \
    composer global require "laravel/installer"; \
    echo "export PATH=$HOME/.composer/vendor/bin:$PATH" >> /root/.bashrc; \
    rm -rf ~/*

RUN groupadd --gid 1000 node \
    && useradd --uid 1000 --gid node --shell /bin/bash --create-home node; \
    apt-get update -y && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends gnupg dirmngr && rm -rf /var/lib/apt/lists/*

# gpg keys listed at https://github.com/nodejs/node#release-team
RUN set -ex \
    && for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    ; do \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done

ENV NODE_VERSION 10.4.1

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
    && mv /usr/local/bin/npm /usr/local/bin/npm-original

ENV YARN_VERSION 1.7.0

RUN set -ex \
    && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
    ; do \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
    && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
    && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
    && mkdir -p /opt \
    && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
    && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
    && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
    && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz; \
    { \
    echo "alias npm='npm-original \\"; \
    echo "            --registry=https://registry.npm.taobao.org \\"; \
    echo "            --disturl=https://npm.taobao.org/dist \\"; \
    echo "            --userconfig=$HOME/.cnpmrc \\"; \
    echo "            --cache=$HOME/.npm/.cache/cnpm'"; \
    } >> /root/.bashrc

ENTRYPOINT ["docker-php-entrypoint"]
CMD ["apache2-foreground"]
