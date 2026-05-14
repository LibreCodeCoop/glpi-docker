[![logo](https://raw.githubusercontent.com/glpi-project/glpi/main/public/pics/logos/logo-GLPI-250-black.png)](https://github.com/glpi-project/glpi)

[![Publish GLPI Images](https://github.com/LibreCodeCoop/glpi-docker/actions/workflows/publish-images.yml/badge.svg)](https://github.com/LibreCodeCoop/glpi-docker/actions/workflows/publish-images.yml)
# GLPI in Docker
Run GLPI in a Docker

Quick and simple installation of GLPI using docker-compose

## Sign
If you need to sign your tickets with LibreSign, take a look at this [plugin](https://github.com/LibreSign/libresign-glpi)

## Setup

* Clone this repository
* Copy `.env.example` file to `.env`
* Define a value to environment `VERSION_GLPI`
* Run command `docker-compose up`
* Follow instructions to end setup in browser

If the database already contains `glpi_*` tables and you want to recreate the installation, set `GLPI_DB_FORCE_INSTALL=1` before starting the `app` service. This makes the container run `bin/console --no-interaction db:install --force --reconfigure`.

### Install plugins and run extra commands

Fill the environment `EXTRA_COMMANDS` with the command you want run on the first execution.

**Examples**:
```bash
EXTRA_COMMANDS="
curl -L https://github.com/pluginsGLPI/formcreator/releases/download/v2.11.2/glpi-formcreator-2.11.2.tar.bz2 | tar -jxf - -C /var/www/glpi/plugins/;
curl -L https://github.com/LibreSign/libresign-glpi/archive/refs/tags/v1.0.0.tar.gz | tar -zxf - -C /var/www/glpi/plugins/;
mv /var/www/html/plugins/libresign-glpi-1.0.0 /var/www/glpi/plugins;
"
```

## Default accounts

| account  | password | type              |
| -------- | -------- | ----------------- |
| glpi     | glpi     | super-admin       |
| tech     | tech     |                   |
| postonly | postonly | only for helpdesk |
| normal   | normal   |                   |

> **PS**: Change all password after setup by security reasons
