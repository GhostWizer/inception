#!/bin/sh
set -eu

: "${DOMAIN_NAME:?need DOMAIN_NAME}"

mkdir -p /etc/ssl/certs /etc/ssl/private

if [ ! -f /etc/ssl/certs/server.crt ] || [ ! -f /etc/ssl/private/server.key ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/server.key \
        -out /etc/ssl/certs/server.crt \
        -subj "/C=FR/ST=Paris/L=Paris/O=42/OU=Inception/CN=${DOMAIN_NAME}"
fi

# Inject the domain name into the nginx config
sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN_NAME}|g" /etc/nginx/nginx.conf

exec nginx -g 'daemon off;'
