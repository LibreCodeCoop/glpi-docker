#!/bin/bash

# Set uid of host machine
usermod --non-unique --uid "${HOST_UID}" www-data
groupmod --non-unique --gid "${HOST_GID}" www-data

installed_version="0.0.0"
if [ -e /var/www/glpi/inc/define.php ]; then
    installed_version=`grep -oP "define\('GLPI_VERSION', '\K((\d\.?)+)" /var/www/glpi/inc/define.php`
fi

image_version=`grep -oP "define\('GLPI_VERSION', '\K((\d\.?)+)" /usr/src/glpi/inc/define.php`

version_greater() {
    [ "$(printf '%s\n' "$@" | sort -t '.' -n -k1,1 -k2,2 -k3,3 -k4,4 | head -n 1)" != "$1" ]
}

if version_greater "$installed_version" "$image_version"; then
    echo "Can't start GLPI because the version of the data ($installed_version) is higher than the docker image version ($image_version) and downgrading is not supported. Are you sure you have pulled the newest image version?"
    exit 1
fi

if version_greater "$image_version" "$installed_version"; then
    echo "⌛️ Initializing GLPI $image_version ..."
    if [ "$installed_version" != "0.0.0" ]; then
        echo "⌛️ Upgrading GLPI from $installed_version ..."
    fi

    if [ "$(id -u)" = 0 ]; then
        rsync_options="-rlDog --chown www-data:root"
    else
        rsync_options="-rlD"
    fi
    rsync $rsync_options /usr/src/glpi/ /var/www/glpi/
    chown -R www-data:www-data /var/www/glpi/
    echo "Initializing finished"

    echo "🌐 Compiling locales"
    php bin/console locales:compile

    #install
    echo "🔧 Starting dependencies installation"
    php bin/console dependencies install

    echo "📁 Creating directories"
    bash -c 'mkdir -pv $GLPI_VAR_DIR/{_cron,_dumps,_graphs,_log,_lock,_pictures,_plugins,_rss,_tmp,_uploads,_cache,_sessions,_locales}'
    bash -c 'mkdir -pv /var/www/glpi/marketplace'
    bash -c 'chown -R www-data:www-data /var/www/glpi'
    bash -c 'chown -R www-data:www-data {/var/www/glpi,$GLPI_CONFIG_DIR,$GLPI_VAR_DIR}'

    echo "Check requirements"
    php bin/console glpi:system:check_requirements

    echo "📊 Install database"
    printf "Yes\n" | php bin/console db:install --db-host=$MYSQL_HOST --db-name=$MYSQL_DATABASE --db-user=$MYSQL_USER --db-password=$MYSQL_PASSWORD
    if [ -n "$EXTRA_COMMANDS" ]; then
        eval $EXTRA_COMMANDS
    fi

    # fix permissions after install database
    rm install/install.php
    bash -c 'chown -R www-data:www-data {/var/www/glpi,$GLPI_CONFIG_DIR,$GLPI_VAR_DIR}'

    php bin/console glpi:system:status
    echo "🥳 🏁 Setup completed !!!"
fi

exec "$@"