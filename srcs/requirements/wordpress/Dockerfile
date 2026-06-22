FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    php-fpm php-mysql php-curl php-gd php-mbstring php-xml \
    curl mariadb-client less unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

RUN mkdir -p /var/www/html /run/php
WORKDIR /var/www/html

COPY tools/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
