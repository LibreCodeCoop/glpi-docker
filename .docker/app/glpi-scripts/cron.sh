#!/bin/sh
set -eu

# Wait for the app container to populate the shared GLPI volume.
while [ ! -f /var/www/glpi/front/cron.php ]; do
    echo "Waiting for GLPI files in /var/www/glpi..."
    sleep 5
done

exec busybox crond -f -l 0 -L /dev/stdout
