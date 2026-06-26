# User documentation

For anyone who wants to deploy Inception, either locally for testing or on a Linux VM for the 42 submission.

## Environment variables

The whole configuration lives in `srcs/.env`, created from `srcs/.env.example`. Compose does not provide default values, so every variable must be set.

| Variable | Description |
|---|---|
| `DOMAIN_NAME` | Domain served by Nginx, e.g. `jhubier.42.fr`. |
| `DATA_PATH` | Host path where Docker bind-mounts the data (subfolders `wordpress` and `mariadb` are created under it). |
| `MYSQL_DATABASE` | WordPress database name. |
| `MYSQL_USER` / `MYSQL_PASSWORD` | MariaDB application user. |
| `MYSQL_ROOT_PASSWORD` | MariaDB root password. |
| `WORDPRESS_DB_*` | Same values seen from WordPress's side. Must match `MYSQL_*`. |
| `WP_ADMIN_USER` | WordPress admin. **Must not contain `admin`, `Admin`, `administrator`, etc.** |
| `WP_ADMIN_PASSWORD` / `WP_ADMIN_EMAIL` | Admin credentials. |
| `WP_USER` / `WP_USER_PASSWORD` / `WP_USER_EMAIL` | Second user, created with the `author` role. |

## Install on a Debian Linux VM (42 submission)

### 1. Prepare the VM

A fresh Debian 12 VM, a non-root user in the `sudo` group, SSH enabled, NAT networking.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git make ca-certificates
```

### 2. Install Docker

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
```

Log out and back in to activate the docker group.

### 3. Clone and configure

```bash
cd ~
git clone <repo-url> inception
cd inception
cp srcs/.env.example srcs/.env
nano srcs/.env
```

In `.env` set:
- `DOMAIN_NAME=<login>.42.fr`
- `DATA_PATH=/home/<login>/data`
- All passwords (alphanumeric only to avoid escaping issues).

### 4. Prepare the host

```bash
mkdir -p ~/data/wordpress ~/data/mariadb
echo "127.0.0.1 <login>.42.fr" | sudo tee -a /etc/hosts
```

### 5. Start

```bash
make up
docker ps
```

The first launch takes ~30 s while WordPress installs (core download, `wp-config.php` generation, database init, two users created). Follow with `docker logs -f wordpress`.

Once ready, open `https://<login>.42.fr/` in Firefox inside the VM and accept the self-signed certificate.

## Install locally on WSL2 (Windows)

Same procedure, with:
- WSL2 + Ubuntu + Docker Desktop with WSL integration enabled.
- Clone the project under `~/projects/inception` on the Linux side (not under `/mnt/c/`).
- `DATA_PATH=/home/<wsl-user>/data` in `.env`.
- Also add `127.0.0.1 <login>.42.fr` to `C:\Windows\System32\drivers\etc\hosts` to reach it from a Windows browser.

## Day-to-day usage

| Action | Command |
|---|---|
| Start | `make up` |
| Stop (keep data) | `make down` |
| Wipe everything (data included) | `make clean && rm -rf $DATA_PATH/*` |
| Logs for a service | `docker logs -f <service>` (`nginx`, `wordpress`, `mariadb`) |
| Shell inside a container | `docker exec -it <service> bash` |
| Force WP reinstall | delete `$DATA_PATH/wordpress/wp-config.php`, then `make down && make up` |

## Backup and restore

Everything lives under `$DATA_PATH`. Backup:

```bash
make down
tar czf inception-backup-$(date +%F).tar.gz -C $DATA_PATH .
make up
```

Restore: extract the archive back into `$DATA_PATH/`, then `make up`.

## Troubleshooting

- **403 from Nginx**: `/var/www/html` is empty. Check `docker logs wordpress` to see whether the install succeeded.
- **WP loops on "Waiting for mariadb"**: credentials mismatch. Make sure `MYSQL_USER == WORDPRESS_DB_USER` and same for the password.
- **Broken WP internal links**: the `siteurl` in the database does not match the URL you browse from. Fix: `docker exec wordpress wp option update siteurl "https://<domain>" --allow-root` (same for `home`).
- **TLS certificate rejected**: expected, it is self-signed. Accept the exception in the browser.
