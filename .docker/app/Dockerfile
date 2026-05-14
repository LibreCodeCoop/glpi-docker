ARG version_php
ARG version_glpi

FROM php:${version_php}-fpm AS base
ARG version_glpi

ENV VERSION_GLPI=${version_glpi}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gettext \
        git \
        rsync \
        unzip \
        libzip-dev \
    # Install node
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install --no-install-recommends -y nodejs \
    && node --version \
    && npm --version \
    # Install cron dependencies
    && apt-get install --no-install-recommends -y cron busybox-static \
    && mkdir -p /var/spool/cron/crontabs \
    && echo '*/5 * * * * php -f /var/www/glpi/front/cron.php' > /var/spool/cron/crontabs/www-data

# Install PHP extensions
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod uga+x /usr/local/bin/install-php-extensions \
    && install-php-extensions \
    bcmath \
    bz2 \
    exif \
    gd \
    intl \
    ldap \
    mysqli \
    opcache \
    zip

RUN git clone --progress -b "${VERSION_GLPI}" --single-branch --depth 1 https://github.com/glpi-project/glpi.git /usr/src/glpi
RUN git config --system --add safe.directory /var/www/glpi \
    && git config --system --add safe.directory /usr/src/glpi

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /usr/src/glpi
RUN rm -rf .git \
    && sed -i 's#bin/console dependencies install#bin/console dependencies install --allow-superuser#' tools/build_glpi.sh \
    && sed -i 's#bin/console tools:locales:compile#bin/console tools:locales:compile --allow-superuser#' tools/build_glpi.sh \
    && sed -i 's#bin/console build:compile_scss#bin/console build:compile_scss --allow-superuser#' tools/build_glpi.sh \
    && sed -i 's#bin/console build:generate_code_manifest -a crc32c#bin/console build:generate_code_manifest -a crc32c --allow-superuser#' tools/build_glpi.sh \
    && tools/build_glpi.sh

# RUN apt-get update
# ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
# RUN chmod uga+x /usr/local/bin/install-php-extensions \
#     && install-php-extensions xdebug

VOLUME /var/www/glpi
WORKDIR /var/www/glpi

COPY glpi-scripts /usr/src/glpi-scripts
COPY config/* /usr/local/etc/php/conf.d/
RUN chmod +x /usr/src/glpi-scripts/*.sh

FROM base AS cron
ENTRYPOINT ["/usr/src/glpi-scripts/cron.sh"]

FROM base AS app
ENTRYPOINT ["/usr/src/glpi-scripts/entrypoint.sh"]

CMD ["php-fpm"]
