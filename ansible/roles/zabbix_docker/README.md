This role installs Docker CE + docker compose plugin, writes /opt/zabbix/docker-compose.yml,
starts MySQL first, bootstraps Zabbix schema from:

/usr/share/doc/zabbix-server-mysql/create.sql.gz

only if the `users` table is missing or empty, then starts the full stack.
