# Developer documentation

For a developer setting up, building, or extending this stack.

## Setting up the environment from scratch

### Prerequisites

On the host machine (Linux VM or WSL2 Ubuntu):

| Tool | Why |
|---|---|
| Docker Engine ≥ 24 | Containers runtime |
| Docker Compose v2 (`docker compose`, not `docker-compose`) | Orchestration |
| GNU Make | Entry point of all common commands |
| Git | Project source |

Standard install on Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y curl git make ca-certificates gnupg lsb-release
# Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
# Re-login after this command
```

### Configuration files

```
inception/
├── Makefile                          standard entry points
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── .env                          secrets (gitignored)
    ├── .env.example                  template
    ├── docker-compose.yaml           three services on one bridge network
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile            Debian + nginx + openssl
        │   ├── conf/nginx.conf       TLS 1.2/1.3, FastCGI to wordpress
        │   └── tools/entrypoint.sh   cert generation, domain injection
        ├── wordpress/
        │   ├── Dockerfile            Debian + php-fpm + wp-cli
        │   └── tools/entrypoint.sh   wait for DB, install WP, two users
        └── mariadb/
            ├── Dockerfile            Debian + mariadb-server
            └── tools/entrypoint.sh   first-run init, idempotent restart
```

### Secrets

All secrets are in `srcs/.env`. The file is gitignored (see `.gitignore`). It is loaded once by `docker compose` (for variable substitution in the YAML) and injected into each container via `env_file:`.

No secret is duplicated in Dockerfiles, scripts, or the compose file.

To bootstrap: `cp srcs/.env.example srcs/.env` then edit. Fill in every variable; nothing has a default.

## Building and launching with Makefile and Docker Compose

The Makefile is a thin wrapper around `docker compose`. The target `make up` ensures the bind-mount directories exist before starting.

```bash
make up        # docker compose up -d --build (and mkdir -p the data dirs)
make down      # docker compose down
make clean     # docker compose down -v --rmi all --remove-orphans
make re        # clean + up
make logs      # docker compose logs -f
```

Direct `docker compose` invocation:

```bash
docker compose -f srcs/docker-compose.yaml up -d --build
docker compose -f srcs/docker-compose.yaml ps
docker compose -f srcs/docker-compose.yaml logs -f nginx
docker compose -f srcs/docker-compose.yaml down
```

## Managing containers and volumes

| Goal | Command |
|---|---|
| List containers | `docker ps` |
| Shell inside a container | `docker exec -it <service> bash` |
| Tail one service's logs | `docker logs -f <service>` |
| Inspect the network | `docker network inspect inception` |
| Inspect a volume | `docker volume inspect <name>` |
| List volumes | `docker volume ls` |
| Remove a stopped container | `docker rm <name>` |
| Remove all stopped containers + dangling images | `docker system prune -af` |
| Remove all unused volumes | `docker volume prune -f` |
| Force WP reinstall | `rm $DATA_PATH/wordpress/wp-config.php && make down && make up` |
| Force MariaDB reinit | `rm $DATA_PATH/mariadb/.inception_initialized && make down && make up` |

## Where the data is stored and how it persists

The two stateful volumes (`wordpress_data`, `mariadb_data`) are declared as bind-mounts in the compose file:

```yaml
wordpress_data:
  driver: local
  driver_opts:
    type: none
    o: bind
    device: ${DATA_PATH}/wordpress
```

This means:
- The bytes physically live on the **host filesystem** under `$DATA_PATH/wordpress` and `$DATA_PATH/mariadb`.
- They are visible to the host user (`ls $DATA_PATH/...`), backup-able with `tar`, and survive any Docker operation — including `make clean` (`docker compose down -v` only removes Docker-managed volumes, not host-side bind mounts).
- After a VM reboot, the data is still there. `make up` starts containers that mount the same host paths and pick up where they left off.

To truly wipe data: `rm -rf $DATA_PATH/*` (plus `.inception_initialized` if present).

The third "implicit" volume is the embedded SSL cert in the Nginx container, regenerated on each image build via `openssl req -x509`. Not persisted because it is cheap to recreate and auto-signed anyway.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `make up` aborts with "bind: device or resource busy" or "no such file" | `$DATA_PATH/...` doesn't exist | `make up` now creates them; if a stale Docker mount caches an old path, `make clean && make up` |
| 403 on `https://<DOMAIN_NAME>/` | WP install didn't finish, `/var/www/html` empty | `docker logs wordpress` shows what failed |
| WordPress loops on "Waiting for mariadb..." | Credentials mismatch | `MYSQL_USER`/`MYSQL_PASSWORD` must equal `WORDPRESS_DB_USER`/`WORDPRESS_DB_PASSWORD` |
| Internal WP links broken | `siteurl` in DB ≠ access URL | The entrypoint now re-syncs `siteurl`/`home` to `DOMAIN_NAME` on every start |
| Comments don't appear | WP holds them for moderation | Approve via admin panel or `wp comment approve <id> --allow-root` |
| Container restart loop | Crash inside entrypoint | `docker logs <service>` |
