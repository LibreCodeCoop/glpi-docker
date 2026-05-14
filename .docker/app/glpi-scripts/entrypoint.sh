#!/bin/bash

set -euo pipefail

# Set uid of host machine
usermod --non-unique --uid "${HOST_UID}" www-data
groupmod --non-unique --gid "${HOST_GID}" www-data

resolve_glpi_version() {
    local glpi_dir="$1"
    local version=""

    if [ -e "${glpi_dir}/inc/define.php" ]; then
        version=$(grep -oP "define\('GLPI_VERSION', '\K((\d\.?)+)" "${glpi_dir}/inc/define.php" || true)
    fi

    if [ -z "$version" ] && [ -f "${glpi_dir}/bin/console" ]; then
        version=$(cd "$glpi_dir" && php bin/console --no-interaction --no-ansi --version 2>/dev/null | grep -oP '\d+(\.\d+)+' || true)
    fi

    printf '%s\n' "$version"
}

installed_version="$(resolve_glpi_version /var/www/glpi)"
installed_version="${installed_version:-0.0.0}"

image_version="${VERSION_GLPI:-0.0.0}"

version_greater() {
    [ "$(printf '%s\n' "$@" | sort -t '.' -n -k1,1 -k2,2 -k3,3 -k4,4 | head -n 1)" != "$1" ]
}

run_glpi_console() {
    php bin/console --allow-superuser "$@"
}

write_downstream_config() {
    cat > /var/www/glpi/inc/downstream.php <<EOF
<?php
define('GLPI_CONFIG_DIR', '${GLPI_CONFIG_DIR}/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF

    cat > "${GLPI_CONFIG_DIR}/local_define.php" <<EOF
<?php
define('GLPI_VAR_DIR', '${GLPI_VAR_DIR}');
define('GLPI_DOC_DIR', GLPI_VAR_DIR);
define('GLPI_CACHE_DIR', GLPI_VAR_DIR . '/_cache');
define('GLPI_CRON_DIR', GLPI_VAR_DIR . '/_cron');
define('GLPI_DUMP_DIR', GLPI_VAR_DIR . '/_dumps');
define('GLPI_GRAPH_DIR', GLPI_VAR_DIR . '/_graphs');
define('GLPI_LOCAL_I18N_DIR', GLPI_VAR_DIR . '/_locales');
define('GLPI_LOCK_DIR', GLPI_VAR_DIR . '/_lock');
define('GLPI_PICTURE_DIR', GLPI_VAR_DIR . '/_pictures');
define('GLPI_PLUGIN_DOC_DIR', GLPI_VAR_DIR . '/_plugins');
define('GLPI_RSS_DIR', GLPI_VAR_DIR . '/_rss');
define('GLPI_SESSION_DIR', GLPI_VAR_DIR . '/_sessions');
define('GLPI_TMP_DIR', GLPI_VAR_DIR . '/_tmp');
define('GLPI_UPLOAD_DIR', GLPI_VAR_DIR . '/_uploads');
EOF
}

patch_glpi_console_runtime() {
    local locales_command="/var/www/glpi/tools/src/Command/LocalesCompileCommand.php"

    if [ -f "$locales_command" ]; then
        sed -i "s/final class LocalesCompileCommand extends AbstractCommand/final class LocalesCompileCommand extends \\\\Glpi\\\\Console\\\\AbstractCommand/" "$locales_command"
    fi
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

    echo "📁 Creating directories"
    bash -c 'mkdir -pv $GLPI_VAR_DIR/{_cron,_dumps,_graphs,_log,_lock,_pictures,_plugins,_rss,_tmp,_uploads,_cache,_sessions,_locales}'
    bash -c 'mkdir -pv /var/www/glpi/marketplace'
    write_downstream_config
    patch_glpi_console_runtime
    bash -c 'chown -R www-data:www-data /var/www/glpi'
    bash -c 'chown -R www-data:www-data {/var/www/glpi,$GLPI_CONFIG_DIR,$GLPI_VAR_DIR}'

    echo "Check requirements"
    run_glpi_console glpi:system:check_requirements

    echo "📊 Install database"
    printf "Yes\n" | run_glpi_console db:install --db-host=$MYSQL_HOST --db-name=$MYSQL_DATABASE --db-user=$MYSQL_USER --db-password=$MYSQL_PASSWORD
    if [ -n "$EXTRA_COMMANDS" ]; then
        eval $EXTRA_COMMANDS
    fi

    # fix permissions after install database
    rm install/install.php
    bash -c 'chown -R www-data:www-data {/var/www/glpi,$GLPI_CONFIG_DIR,$GLPI_VAR_DIR}'

    run_glpi_console glpi:system:status
    echo "🥳 🏁 Setup completed !!!"
fi

exec "$@"
