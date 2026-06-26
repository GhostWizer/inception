#!/bin/sh
set -eu

DATADIR=/var/lib/mysql

# The init binary name varies across Debian/MariaDB versions
if command -v mariadb-install-db >/dev/null 2>&1; then
    INSTALL_DB=mariadb-install-db
elif command -v mysql_install_db >/dev/null 2>&1; then
    INSTALL_DB=mysql_install_db
else
    echo "[mariadb] FATAL: no init binary found" >&2
    exit 1
fi

# Client binary detection
if command -v mariadb >/dev/null 2>&1; then
    CLIENT=mariadb
else
    CLIENT=mysql
fi

# Admin binary detection
if command -v mariadb-admin >/dev/null 2>&1; then
    ADMIN=mariadb-admin
else
    ADMIN=mysqladmin
fi


# Required environment variables sanity check
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"

# Datadir must be owned by mysql (volumes sometimes mount as root)
mkdir -p "$DATADIR"
chown -R mysql:mysql "$DATADIR"

# /run/mysqld is required for the unix socket and does not persist across restarts
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# First run: system tables missing, OR previous init was interrupted
NEED_INIT=0
if [ ! -d "$DATADIR/mysql" ]; then
    NEED_INIT=1
elif [ ! -f "$DATADIR/.inception_initialized" ]; then
    echo "[mariadb] System tables present but init incomplete, replaying."
    NEED_INIT=1
fi

if [ "$NEED_INIT" = "1" ]; then
    # Wipe any partial state to start fresh
    rm -rf "$DATADIR"/*
    echo "[mariadb] Initializing system tables with $INSTALL_DB..."
    "$INSTALL_DB" --user=mysql --datadir="$DATADIR" --auth-root-authentication-method=normal

    echo "[mariadb] Starting temporary server (socket only)..."
    mariadbd --user=mysql --datadir="$DATADIR" --skip-networking --socket=/tmp/mysql_init.sock &
    PID=$!

    # Wait for the socket to be ready
    for i in $(seq 1 30); do
        if "$CLIENT" --socket=/tmp/mysql_init.sock -uroot -e "SELECT 1" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    echo "[mariadb] Creating database and users..."
    "$CLIENT" --socket=/tmp/mysql_init.sock -uroot <<EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

    echo "[mariadb] Stopping temporary server..."
    "$ADMIN" --socket=/tmp/mysql_init.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait "$PID" || true

    # Marker: init complete, do not replay on next start
    touch "$DATADIR/.inception_initialized"
fi

echo "[mariadb] Starting in foreground..."
exec mariadbd --user=mysql --datadir="$DATADIR" --bind-address=0.0.0.0
