#!/bin/sh

set -e

mkdir -p /etc/ssl/certs /etc/ssl/private

if [ ! -f /etc/ssl/certs/server.crt ] || [ ! -f /etc/ssl/private/server.key ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/server.key \
        -out /etc/ssl/certs/server.crt \
        -subj "/C=FR/ST=Paris/L=Paris/O=42/OU=Inception/CN=localhost"
fi

nginx -g 'daemon off;'
