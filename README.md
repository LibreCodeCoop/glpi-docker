[![logo](https://raw.githubusercontent.com/glpi-project/glpi/master/pics/logos/logo-GLPI-250-black.png)](https://github.com/glpi-project/glpi)

# GLPI in Docker
Run GLPI in a Docker

Quick and simple installation of GLPI using docker-compose

## Setup

* Clone this repository
* Copy `.env.example` file to `.env`
* Define a value to environment `VERSION_GLPI`
* Run command `docker-compose up`
* Follow instructions to end setup in browser

## Default accounts

| account  | password | type              |
| -------- | -------- | ----------------- |
| glpi     | glpi     | super-admin       |
| tech     | tech     |                   |
| postonly | postonly | only for helpdesk |
| normal   | normal   |                   |

> **PS**: Change all password after setup by security reasons
