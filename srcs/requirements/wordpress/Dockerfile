FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y php-fpm php-mysql curl tar && rm -rf /var/lib/apt/lists/*

COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
