# User documentation

For an end user or administrator running this stack.

## What services are provided

The stack provides a fully self-hosted WordPress site over HTTPS, made of three cooperating services:

| Service | Role |
|---|---|
| **Nginx** | Public entry point on port 443. Terminates TLS (1.2/1.3) with a self-signed certificate, serves static files, forwards PHP requests to WordPress. |
| **WordPress** | The PHP application itself, running on php-fpm. Handles pages, posts, comments, admin panel. |
| **MariaDB** | Database backend, only reachable from the WordPress container. Stores all WP data. |

The three services are isolated on a private Docker network and persist their data on the host under `$DATA_PATH`.

## Starting and stopping the project

From the repository root.

| Action | Command |
|---|---|
| First-time launch (build + start) | `make up` |
| Stop everything (keep data) | `make down` |
| Restart after a stop | `make up` |
| Wipe images and Docker state (data files on host stay) | `make clean` |
| Full wipe including data | `make clean && rm -rf $DATA_PATH/*` |
| Rebuild from scratch (clean + up) | `make re` |
| Tail logs of all services | `make logs` |

## Accessing the website and admin panel

Both URLs require an entry in your `/etc/hosts` (`127.0.0.1 <DOMAIN_NAME>`) and acceptance of the self-signed certificate.

- **Public site** → `https://<DOMAIN_NAME>/`
- **Admin login** → `https://<DOMAIN_NAME>/wp-login.php` (or `/wp-admin/`)

Credentials are taken from `srcs/.env`:
- Admin user: `WP_ADMIN_USER` / `WP_ADMIN_PASSWORD`
- Regular user: `WP_USER` / `WP_USER_PASSWORD`

## Locating and managing credentials

All credentials live in **`srcs/.env`**, which is gitignored. It is created by copying `srcs/.env.example` and filling in every variable. None of the credentials are duplicated anywhere else in the code.

| Variable | Used by |
|---|---|
| `MYSQL_ROOT_PASSWORD` | MariaDB root account |
| `MYSQL_USER` / `MYSQL_PASSWORD` | MariaDB application account, used by WordPress |
| `MYSQL_DATABASE` | The WordPress database name |
| `WORDPRESS_DB_*` | Must match the `MYSQL_*` values (WordPress reuses them) |
| `WP_ADMIN_*` | WordPress administrator |
| `WP_USER_*` | Second WordPress user (author role) |
| `DOMAIN_NAME` | The hostname Nginx serves |
| `DATA_PATH` | Host directory where the two volumes are bind-mounted |

To rotate a password: edit `srcs/.env`, then `make clean && rm -rf $DATA_PATH/* && make up` (a partial restart is not enough since MariaDB stores hashed passwords in its volume).

## Checking that the services are running correctly

```bash
docker compose -f srcs/docker-compose.yaml ps     # three containers, status Up
make logs                                          # follow logs of all services
docker logs nginx                                  # individual log
docker logs wordpress
docker logs mariadb
```

Healthy signs:
- `nginx` is `Up` and publishes `0.0.0.0:443->443/tcp`.
- `wordpress` log ends with `Starting php-fpm...` and stays running.
- `mariadb` log ends with `mariadbd: ready for connections.` on socket `:3306`.

Quick functional check:
```bash
curl -kI https://<DOMAIN_NAME>/                       # HTTP/1.1 200 OK
curl -v http://<DOMAIN_NAME>/ 2>&1 | grep refused     # connection refused = expected
```

If something is wrong, see the Troubleshooting section in [DEV_DOC.md](DEV_DOC.md).
