#!/bin/sh
set -eu

DATADIR=/var/lib/mysql

# Detect the install binary name (varies across Debian/MariaDB versions)
if command -v mariadb-install-db >/dev/null 2>&1; then
    INSTALL_DB=mariadb-install-db
elif command -v mysql_install_db >/dev/null 2>&1; then
    INSTALL_DB=mysql_install_db
else
    echo "[mariadb] FATAL: no install-db binary found" >&2
    exit 1
fi

# Detect client binary
if command -v mariadb >/dev/null 2>&1; then
    CLIENT=mariadb
else
    CLIENT=mysql
fi

# Detect admin binary
if command -v mariadb-admin >/dev/null 2>&1; then
    ADMIN=mariadb-admin
else
    ADMIN=mysqladmin
fi


# Sanity check env
: "${MYSQL_ROOT_PASSWORD:?need MYSQL_ROOT_PASSWORD}"
: "${MYSQL_DATABASE:?need MYSQL_DATABASE}"
: "${MYSQL_USER:?need MYSQL_USER}"
: "${MYSQL_PASSWORD:?need MYSQL_PASSWORD}"

# Make sure datadir is owned by mysql (volumes sometimes mount as root)
mkdir -p "$DATADIR"
chown -R mysql:mysql "$DATADIR"

# /run/mysqld is required for the unix socket; it does not survive container restarts
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# First-run init: system tables absent OR previous init was interrupted
NEED_INIT=0
if [ ! -d "$DATADIR/mysql" ]; then
    NEED_INIT=1
elif [ ! -f "$DATADIR/.inception_initialized" ]; then
    echo "[mariadb] System tables présentes mais init incomplète, on rejoue."
    NEED_INIT=1
fi

if [ "$NEED_INIT" = "1" ]; then
    # Wipe any partial state to allow mariadb-install-db to run cleanly
    rm -rf "$DATADIR"/*
    echo "[mariadb] Init des system tables avec $INSTALL_DB..."
    "$INSTALL_DB" --user=mysql --datadir="$DATADIR" --auth-root-authentication-method=normal

    echo "[mariadb] Démarrage temporaire (socket only)..."
    mariadbd --user=mysql --datadir="$DATADIR" --skip-networking --socket=/tmp/mysql_init.sock &
    PID=$!

    # Wait for socket to be ready
    for i in $(seq 1 30); do
        if "$CLIENT" --socket=/tmp/mysql_init.sock -uroot -e "SELECT 1" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    echo "[mariadb] Création DB + utilisateurs..."
    "$CLIENT" --socket=/tmp/mysql_init.sock -uroot <<EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

    echo "[mariadb] Arrêt du serveur temporaire..."
    "$ADMIN" --socket=/tmp/mysql_init.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait "$PID" || true

    # Marker file: init pipeline reached the end
    touch "$DATADIR/.inception_initialized"
fi

echo "[mariadb] Démarrage en mode foreground..."
exec mariadbd --user=mysql --datadir="$DATADIR" --bind-address=0.0.0.0
