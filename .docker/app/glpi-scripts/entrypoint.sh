#!/bin/bash

set -euo pipefail

: "${GLPI_CONFIG_DIR:=/var/www/config}"
: "${GLPI_VAR_DIR:=/var/www/var}"
: "${EXTRA_COMMANDS:=}"
: "${GLPI_DB_FORCE_INSTALL:=0}"

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

should_force_db_install() {
    case "${GLPI_DB_FORCE_INSTALL}" in
        1|true|TRUE|yes|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

write_downstream_config() {
    mkdir -p "${GLPI_CONFIG_DIR}" "${GLPI_VAR_DIR}"

    cat > /var/www/glpi/inc/downstream.php <<EOF
<?php
defined('GLPI_CONFIG_DIR') || define('GLPI_CONFIG_DIR', '${GLPI_CONFIG_DIR}');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF

    cat > "${GLPI_CONFIG_DIR}/local_define.php" <<EOF
<?php
defined('GLPI_VAR_DIR') || define('GLPI_VAR_DIR', '${GLPI_VAR_DIR}');
defined('GLPI_DOC_DIR') || define('GLPI_DOC_DIR', GLPI_VAR_DIR);
defined('GLPI_CACHE_DIR') || define('GLPI_CACHE_DIR', GLPI_VAR_DIR . '/_cache');
defined('GLPI_CRON_DIR') || define('GLPI_CRON_DIR', GLPI_VAR_DIR . '/_cron');
defined('GLPI_DUMP_DIR') || define('GLPI_DUMP_DIR', GLPI_VAR_DIR . '/_dumps');
defined('GLPI_GRAPH_DIR') || define('GLPI_GRAPH_DIR', GLPI_VAR_DIR . '/_graphs');
defined('GLPI_LOCAL_I18N_DIR') || define('GLPI_LOCAL_I18N_DIR', GLPI_VAR_DIR . '/_locales');
defined('GLPI_LOCK_DIR') || define('GLPI_LOCK_DIR', GLPI_VAR_DIR . '/_lock');
defined('GLPI_PICTURE_DIR') || define('GLPI_PICTURE_DIR', GLPI_VAR_DIR . '/_pictures');
defined('GLPI_PLUGIN_DOC_DIR') || define('GLPI_PLUGIN_DOC_DIR', GLPI_VAR_DIR . '/_plugins');
defined('GLPI_RSS_DIR') || define('GLPI_RSS_DIR', GLPI_VAR_DIR . '/_rss');
defined('GLPI_SESSION_DIR') || define('GLPI_SESSION_DIR', GLPI_VAR_DIR . '/_sessions');
defined('GLPI_TMP_DIR') || define('GLPI_TMP_DIR', GLPI_VAR_DIR . '/_tmp');
defined('GLPI_UPLOAD_DIR') || define('GLPI_UPLOAD_DIR', GLPI_VAR_DIR . '/_uploads');
EOF
}

patch_glpi_console_runtime() {
    local shim="/var/www/glpi/tools/src/Command/AbstractCommand.php"

    mkdir -p "$(dirname "$shim")"
    cat > "$shim" <<'EOF'
<?php

namespace Glpi\Tools\Command;

abstract class AbstractCommand extends \Glpi\Console\AbstractCommand
{
}
EOF
}

ensure_glpi_runtime_layout() {
    echo "📁 Ensuring GLPI runtime directories"
    bash -c 'mkdir -pv $GLPI_VAR_DIR/{_cron,_dumps,_graphs,_log,_lock,_pictures,_plugins,_rss,_tmp,_uploads,_cache,_sessions,_locales}'
    bash -c 'mkdir -pv /var/www/glpi/marketplace'
    write_downstream_config
    patch_glpi_console_runtime
    bash -c 'chown -R www-data:www-data {/var/www/glpi,$GLPI_CONFIG_DIR,$GLPI_VAR_DIR}'
}

if version_greater "$installed_version" "$image_version"; then
    echo "Can't start GLPI because the version of the data ($installed_version) is higher than the docker image version ($image_version) and downgrading is not supported. Are you sure you have pulled the newest image version?"
    exit 1
fi

needs_setup=false

if version_greater "$image_version" "$installed_version"; then
    needs_setup=true
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
fi

ensure_glpi_runtime_layout

if [ "$needs_setup" = true ]; then
    echo "Check requirements"
    run_glpi_console glpi:system:check_requirements

    echo "📊 Install database"
    install_args=(
        db:install
        --db-host="$MYSQL_HOST"
        --db-name="$MYSQL_DATABASE"
        --db-user="$MYSQL_USER"
        --db-password="$MYSQL_PASSWORD"
    )
    if should_force_db_install; then
        install_args+=(--force --reconfigure)
    fi
    printf "Yes\n" | run_glpi_console "${install_args[@]}"
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
