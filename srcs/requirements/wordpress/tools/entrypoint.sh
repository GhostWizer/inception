#!/bin/sh
set -e

cd /var/www/html

echo "[wordpress] Waiting for mariadb..."
until mariadb -h"${WORDPRESS_DB_HOST}" -u"${WORDPRESS_DB_USER}" -p"${WORDPRESS_DB_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
    sleep 2
done
echo "[wordpress] mariadb is ready."

if [ ! -f wp-config.php ]; then
    echo "[wordpress] Downloading WordPress core..."
    wp core download --allow-root

    echo "[wordpress] Generating wp-config.php..."
    wp config create --allow-root \
        --dbname="${WORDPRESS_DB_NAME}" \
        --dbuser="${WORDPRESS_DB_USER}" \
        --dbpass="${WORDPRESS_DB_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST}"

    echo "[wordpress] Installing WordPress..."
    wp core install --allow-root \
        --url="${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email

    echo "[wordpress] Creating second user..."
    wp user create --allow-root \
        "${WP_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=author
fi

if wp core is-installed --allow-root >/dev/null 2>&1; then
    wp option update home    "https://${DOMAIN_NAME}" --allow-root >/dev/null
    wp option update siteurl "https://${DOMAIN_NAME}" --allow-root >/dev/null
fi

# php-fpm must listen on TCP 9000 (not a Unix socket) so nginx can reach it
FPM_POOL=/etc/php/8.2/fpm/pool.d/www.conf
sed -i 's|^listen = .*|listen = 9000|' "$FPM_POOL"

chown -R www-data:www-data /var/www/html

echo "[wordpress] Starting php-fpm..."
exec php-fpm8.2 -F
