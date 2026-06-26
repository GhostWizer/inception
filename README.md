*This project has been created as part of the 42 curriculum by jhubier.*

# Inception

## Description

Inception is a small system-administration project where the goal is to set up a complete web infrastructure made of several Docker containers, each running a single service. The final stack serves a WordPress site behind an Nginx reverse proxy with TLS termination, with MariaDB as its database backend.

The point of the project is to learn the building blocks of modern containerized infrastructure, writing Dockerfiles from scratch, orchestrating multiple services with `docker compose`, isolating them on a private network and persisting their data on the host.

## Instructions

Requirements before first launch.

```bash
git clone <repo-url> inception
cd inception
cp srcs/.env.example srcs/.env
nano srcs/.env                       # fill in DOMAIN_NAME, DATA_PATH, passwords, WP users
mkdir -p $DATA_PATH/wordpress $DATA_PATH/mariadb
echo "127.0.0.1 <DOMAIN_NAME>" | sudo tee -a /etc/hosts
make up
```

`make up` then once it settles, open `https://<DOMAIN_NAME>/` in a browser and accept the self-signed certificate.

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

All three images are built locally from `debian:bookworm-slim`. no premade img

### Main design choices

#### Virtual Machines vs Docker

A VM emulates an entire operating system. Each service running in its own VM gets full isolation but at a high cost

Docker containers share the host kernel and only package needed for a single process. A container starts in milliseconds, is a few tens of megabytes, and dozens of them can run on a laptop.

trade-off: Docker isolation is weaker than VM isolation, so containers are not as safe.

#### Secrets vs Environment Variables

Environment variables are the simplest way to pass credentials to a container: `docker compose` reads a `.env` file and injects the variables into each service.
- They are visible to anyone with `docker inspect`.
- They leak into child processes, sometimes into logs.
- They are read once at startup; need to restart container if changed

Docker Secrets is the more rigorous alternative: each secret is a separate file mounted read-only into the container under `/run/secrets/<name>`, never appears in `inspect`, and is owned by the service that needs it.

For this project we kept the `.env` approach because the subject explicitly allows it and it keeps .sh shorter

#### Docker Network vs Host Network

By default Docker creates a private bridge network for each compose project. Containers on the same bridge can reach each other by their service name

`network: host` removes that isolation entirely: the container shares the host's network namespace and listens directly on host ports.

We use a dedicated bridge because, the subject forbids `network: host`. 

#### Docker Volumes vs Bind Mounts

Both make container data persist beyond the container's lifetime.

A **named volume** (the default) is created and managed by Docker in its own storage area

A **bind mount** maps an explicit host path into the container. 

The Inception subject ask for bind mount

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
