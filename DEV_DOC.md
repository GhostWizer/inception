# Developer documentation

Internal notes on how Inception is built and how to extend it. Useful if you want to understand a design choice, debug a weird behaviour, or add a service.

## Layout

```
.
├── Makefile                     command orchestration
├── README.md                    entry point (subject-compliant)
├── USER_DOC.md                  install and usage
├── DEV_DOC.md                   this file
└── srcs
    ├── .env                     secrets, gitignored
    ├── .env.example             template
    ├── docker-compose.yaml      3-service orchestration
    └── requirements
        ├── mariadb
        │   ├── Dockerfile
        │   ├── conf/my.cnf
        │   └── tools/entrypoint.sh
        ├── nginx
        │   ├── Dockerfile
        │   ├── conf/nginx.conf
        │   └── tools/entrypoint.sh
        └── wordpress
            ├── Dockerfile
            └── tools/entrypoint.sh
```

There is no `wordpress/conf/`: the only config to patch (the php-fpm pool) is rewritten on the fly in the entrypoint, which saves one file.

## Why these choices

### One image per service

Each service runs in its own container, with its own image built locally from `debian:bookworm-slim`. Mandated by the subject, but also consistent with the one-container = one-responsibility = one-PID-1 rule.

### Bind mounts to `$DATA_PATH`

The subject mandates that the data lives under `/home/<login>/data/`. We therefore use named volumes configured as bind mounts via `driver_opts`. Upside: the data is readable and backup-able from the host without going through `docker volume inspect`.

### `restart: always` everywhere

If a container crashes, Docker restarts it. Required for persistence from the user's point of view, and avoids losing the service when the VM reboots.

### No official `nginx:` / `wordpress:` / `mariadb:` images

Forbidden by the subject. We start from Debian and install everything via apt. This forces us to understand the chain (what does `apt install nginx` actually drop in `/etc`, which binary do we run, etc.).

### Self-signed TLS

The subject mandates HTTPS with TLS 1.2/1.3, without access to a real CA. We generate the cert on Nginx startup via `openssl req -x509`. CN is set to `$DOMAIN_NAME` so the browser matches it to the URL.

### No Docker secrets, just `.env`

The `.env` is gitignored and injected into each service via `env_file:` in compose. Enough for the mandatory part. Docker secrets would be cleaner (individual files mounted read-only into `/run/secrets/`) — see the "improvement ideas" section below.

## Service lifecycles

### Nginx

1. `entrypoint.sh` checks `$DOMAIN_NAME`, generates the certificate if missing.
2. Patches `nginx.conf` (`DOMAIN_PLACEHOLDER` → real value).
3. `exec nginx -g 'daemon off;'`.

The cert lives under `/etc/ssl/`. That path is not a volume, so the cert is regenerated on every image rebuild — fine since it's self-signed anyway.

### WordPress

1. `entrypoint.sh` loops until `mariadb -h ... SELECT 1` succeeds.
2. If `wp-config.php` is missing (first run), `wp-cli` downloads the core, generates the config, installs WordPress, creates admin + second user.
3. Patches `www.conf` so php-fpm listens on TCP 9000 (Debian defaults to a Unix socket).
4. `chown -R www-data` so php-fpm can write to `/var/www/html`.
5. `exec php-fpm8.2 -F` (foreground).

The `if [ ! -f wp-config.php ]` guard makes it idempotent: restarts do not reinstall.

### MariaDB

This is the trickiest one. We want a clean initial state without relying on the official MariaDB image that handles everything through env vars.

1. Detect the binaries (`mariadb-install-db` vs `mysql_install_db`, etc.) — varies across Debian versions.
2. Verify the required env vars are set (`set -u` + `: "${VAR:?msg}"`).
3. `chown` of `$DATADIR` (useful because bind mounts sometimes belong to root) and creation of `/run/mysqld` (required for the Unix socket, and not persisted).
4. Decide whether init is needed:
   - If `$DATADIR/mysql` does not exist → yes (first run).
   - If present but the `.inception_initialized` marker is missing → yes (previous init was interrupted, replay).
5. Init = `mariadb-install-db`, then start in the background on a private socket → init SQL (root password, database, user, grants) → shutdown → marker.
6. `exec mariadbd --user=mysql --bind-address=0.0.0.0` (foreground, listens on the Docker network).

The `.inception_initialized` marker is crucial: it ensures that a mid-init crash is detected and recovered on the next start, instead of leaving the container in a zombie state.

## PID 1 and signals

Each entrypoint ends with `exec <real-binary>`. The shell's `exec` replaces the current process (the shell) by the binary without forking. The real daemon takes over PID 1 in the container.

Why it matters:
- `docker stop` sends SIGTERM to PID 1. If that's `sh`, sh ignores SIGTERM by default → Docker waits 10 s then sends SIGKILL → the daemon dies abruptly, no flush, no clean shutdown.
- With `exec`, the daemon receives SIGTERM directly and can close connections, flush caches, exit cleanly.

Verify:
```bash
docker exec mariadb ps -ef | head -3
# UID  PID  PPID  CMD
# mysql  1   0    mariadbd --user=mysql ...
```

If you see `sh /entrypoint.sh` at PID 1, you forgot `exec`.

## Network and DNS

The `inception` bridge (declared in `docker-compose.yaml`) has its own DNS. Each service is resolvable by `container_name`. WordPress connects to MariaDB via `WORDPRESS_DB_HOST=mariadb`, never by IP nor by `localhost`.

No `network: host` (forbidden by the subject, and it would break isolation anyway).

## Compose: what's exposed

Only `nginx` has a `ports:` declaration that publishes to the host (`443:443`). The internal ports 9000 (php-fpm) and 3306 (mariadb) are only reachable from inside the `inception` bridge. The Dockerfiles no longer use `EXPOSE` for those ports: it's purely documentary, not a security mechanism, and can mislead an evaluator.

## Improvement ideas (out of mandatory scope)

- **Docker secrets**: replace `env_file:` with `secrets:` in compose, mount each password individually under `/run/secrets/<name>`. Entrypoints read from those files. More secure (no leak in `docker inspect`).
- **Healthchecks**: add `healthcheck:` blocks in compose so `depends_on` actually waits for MariaDB to be ready, instead of the `until` loop in the WordPress entrypoint.
- **Multi-stage builds**: shrink image sizes by separating build deps from runtime.
- **Structured logs**: currently everything goes to stdout, which is fine. Could be piped into ELK if needed.
- **42 bonus**: Redis cache, FTP, static site, Adminer — each is a new service with its own Dockerfile and compose entry.

## Coding conventions

- Shell scripts use `#!/bin/sh` (POSIX) rather than bash: portable, lighter.
- `set -eu` at the top → fail fast on error or missing variable.
- `exec` as the last line so the real daemon becomes PID 1.
- Log lines in English, prefixed with the service name in brackets: `[mariadb] ...`.

## Known pitfalls

- **`.sh` permissions under Windows**: git on Windows does not preserve the executable bit. Run `find srcs -name "*.sh" -exec chmod +x {} +` after every clone on Linux.
- **CRLF line endings**: editing a `.sh` in Notepad adds `\r`. `sh` chokes on it. Solution: a `.gitattributes` with `*.sh text eol=lf` + `dos2unix` if needed.
- **Stale mariadb volume**: if an init crashed between `mariadb-install-db` and the user creation, the old code stayed stuck. The `.inception_initialized` marker fixes this.
- **WP `siteurl`**: hard-coded in the database at install time. If you change `$DOMAIN_NAME`, either `make clean` (full reset) or run `wp option update siteurl ...` manually.
