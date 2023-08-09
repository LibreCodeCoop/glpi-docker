#!/bin/bash

docker_process_sql --binary-mode <<-EOSQL
    GRANT SELECT ON mysql.time_zone_name TO '$MYSQL_DATABASE'@'%';
    FLUSH PRIVILEGES;
EOSQL
