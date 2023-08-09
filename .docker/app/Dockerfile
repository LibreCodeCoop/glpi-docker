ARG version_php
ARG version_glpi

FROM php:${version_php}-fpm
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
    bz2 \
    exif \
    gd \
    intl \
    ldap \
    mysqli \
    opcache \
    zip

RUN git clone --progress -b "${VERSION_GLPI}" --single-branch --depth 1 https://github.com/glpi-project/glpi.git /usr/src/glpi

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# RUN apt-get update
# ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
# RUN chmod uga+x /usr/local/bin/install-php-extensions \
#     && install-php-extensions xdebug

VOLUME /var/www/glpi
WORKDIR /var/www/glpi

COPY glpi-scripts /usr/src/glpi-scripts
COPY config/* /usr/local/etc/php/conf.d/
ENTRYPOINT ["sh", "/usr/src/glpi-scripts/entrypoint.sh"]

CMD ["php-fpm"]