*This project has been created as part of the 42 curriculum by jhubier.*

# Inception

## Description

Inception is a small system-administration project where the goal is to set up a complete web infrastructure made of several Docker containers, each running a single service. The final stack serves a WordPress site behind an Nginx reverse proxy with TLS termination, with MariaDB as its database backend.

The point of the project is not to build "yet another WordPress install" but to learn the building blocks of modern containerized infrastructure: writing Dockerfiles from scratch, orchestrating multiple services with `docker compose`, isolating them on a private network, persisting their data on the host, handling secrets, and making sure each container respects the one-process-per-container rule.

## Instructions

Requirements on the host: `docker`, `docker compose v2`, `make`, `git`.

```bash
git clone <repo-url> inception
cd inception
cp srcs/.env.example srcs/.env
nano srcs/.env                       # fill in DOMAIN_NAME, DATA_PATH, passwords, WP users
mkdir -p $DATA_PATH/wordpress $DATA_PATH/mariadb
echo "127.0.0.1 <DOMAIN_NAME>" | sudo tee -a /etc/hosts
make up
```

The first launch takes about 30 seconds while WordPress downloads its core, generates `wp-config.php`, initializes the database, and creates the two users. Follow with `docker logs -f wordpress`. Once it settles, open `https://<DOMAIN_NAME>/` in a browser and accept the self-signed certificate.

| Make target | Effect |
|---|---|
| `make up` | Build the three images and start everything in the background |
| `make down` | Stop the containers (volumes persist) |
| `make clean` | Stop, then remove images, volumes and orphan containers |
| `make re` | clean + up |
| `make logs` | tail -f the logs of the three services |

Detailed install/usage notes are in [USER_DOC.md](USER_DOC.md). Internal design notes in [DEV_DOC.md](DEV_DOC.md).

## Project description

The infrastructure is made of three custom-built Docker images, orchestrated by `docker compose`:

```
client HTTPS ──▶ Nginx :443 ──▶ WordPress (php-fpm :9000) ──▶ MariaDB :3306
                  TLS 1.2/1.3        FastCGI                  (internal network only)
```

- **Nginx** is the only entry point. It terminates TLS, serves static files and proxies PHP requests to WordPress over FastCGI.
- **WordPress** runs as `php-fpm` only (no embedded web server). Its files live on a shared volume mounted by Nginx.
- **MariaDB** stores WordPress data. It is never exposed to the host; only the WordPress container reaches it through the internal Docker network.

All three images are built locally from `debian:bookworm-slim`. No pre-built `nginx:`, `wordpress:` or `mariadb:` image is used.

### Main design choices

#### Virtual Machines vs Docker

A VM emulates an entire operating system, including a kernel, on top of a hypervisor. Each service running in its own VM gets full isolation but at a high cost: gigabytes of disk per VM, slow boot, hundreds of megabytes of RAM just for the OS.

Docker containers share the host kernel and only package the userspace needed for a single process. A container starts in milliseconds, is a few tens of megabytes, and dozens of them can run on a laptop. Isolation is achieved through Linux namespaces (pid, net, mount, ipc, uts, user) and cgroups for resource limits.

For Inception, Docker is the right tool because we need three services with strict separation but minimal overhead. A three-VM setup would be heavy and impractical, especially for a school project that must be reproducible from a single `git clone`.

The trade-off: Docker isolation is weaker than VM isolation (a kernel exploit escapes a container), so containers are not a security boundary for hostile workloads. For our use case (cooperating services managed by the same operator) that trade-off is acceptable.

#### Secrets vs Environment Variables

Environment variables are the simplest way to pass credentials to a container: `docker compose` reads a `.env` file and injects the variables into each service. The `.env` file is gitignored. This is what we use for the mandatory part.

Limits of environment variables:
- They are visible to anyone with `docker inspect` access on the host.
- They leak into child processes, sometimes into logs.
- They are read once at startup; rotating them means restarting the container.

Docker Secrets is the more rigorous alternative: each secret is a separate file mounted read-only into the container under `/run/secrets/<name>`, never appears in `inspect`, and is owned by the service that needs it. It requires the services to read from files instead of environment variables, which means adapting the entrypoints.

For this project we kept the `.env` approach because the subject explicitly allows it for the mandatory part and it keeps the entrypoints simple. A Docker Secrets implementation is listed as a follow-up in [DEV_DOC.md](DEV_DOC.md).

#### Docker Network vs Host Network

By default Docker creates a private bridge network for each compose project. Containers on the same bridge can reach each other by their service name (Docker runs an embedded DNS that resolves `mariadb` to the right IP). The host sees the bridge as a virtual interface, and ports are only published to the host if `ports:` is declared.

`network: host` removes that isolation entirely: the container shares the host's network namespace and listens directly on host ports. There is no DNS magic, no port mapping, just the host's interface.

We use a dedicated bridge (`inception`) for two reasons. First, the subject forbids `network: host`. Second, the bridge gives us a layered model where only Nginx publishes a port (443) while WordPress and MariaDB stay invisible from outside. The DNS resolution by service name also keeps configs portable (`WORDPRESS_DB_HOST=mariadb` regardless of IP changes).

#### Docker Volumes vs Bind Mounts

Both make container data persist beyond the container's lifetime, but they differ in where the data lives and who manages it.

A **named volume** (the default) is created and managed by Docker in its own storage area (typically `/var/lib/docker/volumes/`). The user does not need to know where the bytes live; Docker handles backups via `docker volume` commands.

A **bind mount** maps an explicit host path into the container. The user controls the location, the bytes are directly visible in the host filesystem, backups are just `tar` over a directory.

The Inception subject mandates that WordPress files and MariaDB data live under `/home/<login>/data/`, so we configure each "named" volume in the compose file with `driver_opts: type=none, o=bind, device=$DATA_PATH/...`. This gives us the syntactic convenience of named volumes (`wordpress_data:`) with the controlled host location of bind mounts. Best of both.

## Resources

Documentation and articles consulted during the project:
- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Nginx + PHP-FPM + WordPress](https://wordpress.org/documentation/article/nginx/)
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [MariaDB Docker official image notes](https://hub.docker.com/_/mariadb)
- [Debian packages for MariaDB](https://wiki.debian.org/MariaDB)

### AI usage

- Researching the proper way to handle MariaDB first-run initialization in a container
- Reviewing entrypoint shell scripts for `exec`-correctness (PID 1) and signal handling.
- Cross-checking the subject's mandatory requirements against the implementation (TLS protocols, port exposure, container conventions).
- Drafting and structuring this README, USER_DOC and DEV_DOC.

All Dockerfiles, entrypoint logic, configuration choices, and final code were written, reviewed and tested by me. No section of the project was used "as is" from AI without understanding and adapting it.
