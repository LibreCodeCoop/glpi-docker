#!/bin/bash -eu
. $NVM_DIR/nvm.sh

installed_version="0.0.0"
if [ -e /var/www/html/inc/define.php ]; then
    installed_version=`grep -oP "define\('GLPI_VERSION', '\K((\d\.?)+)" /var/www/html/inc/define.php`
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
    echo "Initializing GLPI $image_version ..."
    if [ "$installed_version" != "0.0.0" ]; then
        echo "Upgrading GLPI from $installed_version ..."
    fi

    if [ "$(id -u)" = 0 ]; then
        rsync_options="-rlDog --chown www-data:root"
    else
        rsync_options="-rlD"
    fi
    rsync $rsync_options --delete --exclude-from=/usr/src/glpi-scripts/upgrade.exclude /usr/src/glpi/ /var/www/html/
    echo "Initializing finished"

    #install
    echo "Starting dependencies installation"
    php bin/console dependencies install
fi

exec "$@"