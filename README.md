# Inception

Mini-infrastructure Docker : Nginx (reverse proxy TLS) → WordPress (php-fpm) → MariaDB.

## Architecture

```
client HTTPS ──▶ Nginx :443 ──▶ WordPress :9000 (FastCGI) ──▶ MariaDB :3306
                  (TLS 1.2/1.3)
```

Trois conteneurs, trois images construites localement à partir de Debian, un réseau Docker privé, deux volumes (un pour `/var/www/html`, un pour `/var/lib/mysql`).

## Arborescence

```
.
├── Makefile
├── README.md
└── srcs
    ├── .env              (ignoré par git, secrets)
    ├── .env.example      (template à copier)
    ├── docker-compose.yaml
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

## Variables d'environnement

Copier `srcs/.env.example` vers `srcs/.env` et remplir :

| Variable | Rôle |
|---|---|
| `DOMAIN_NAME` | nom de domaine servi (ex. `xhubier.42.fr`) |
| `MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD` | DB applicative |
| `MYSQL_ROOT_PASSWORD` | root MariaDB |
| `WORDPRESS_DB_*` | mêmes valeurs côté WP |
| `WP_ADMIN_USER` / `WP_ADMIN_PASSWORD` / `WP_ADMIN_EMAIL` | admin WordPress (interdit : `admin`, `Admin`, `administrator`, etc.) |
| `WP_USER` / `WP_USER_PASSWORD` / `WP_USER_EMAIL` | second utilisateur (role author) |

## Commandes Make

| | |
|---|---|
| `make up` | build + lance toute l'infra en arrière-plan |
| `make down` | arrête les conteneurs |
| `make clean` | arrête + supprime images, volumes et orphelins |
| `make re` | clean puis up |

---

## Setup sur PC 42 (VM Linux à partir de zéro)

### 1. Créer la VM dans VirtualBox

1. Télécharger l'ISO Debian 12 (ou Rocky Linux) depuis le site officiel.
2. Ouvrir VirtualBox depuis le poste 42. **Stocker la VM dans `~/goinfre/`** (le `~` standard est purgé entre les sessions, `goinfre` est local au poste et persiste).
3. Nouvelle VM :
   - Nom : `inception`
   - Type : Linux, Debian 64-bit
   - Mémoire : 2048–4096 Mo
   - Disque virtuel : VDI dynamique, ~15 Go, **stocké dans `~/goinfre/`**
4. Settings → Storage → attacher l'ISO Debian.
5. Settings → Network → Adapter 1 : NAT (suffisant pour passer l'éval).
6. Démarrer la VM, suivre l'installateur Debian :
   - Pas d'environnement de bureau (gain de temps et de RAM).
   - Cocher "SSH server" et "standard system utilities".
   - Mot de passe root + user `xhubier`.
7. Une fois Debian installé, éteindre, retirer l'ISO, redémarrer.

### 2. Préparer la VM

Se connecter en TTY (login + password Debian) puis :

```bash
su -
apt update && apt upgrade -y
apt install -y sudo curl git make ca-certificates gnupg lsb-release
usermod -aG sudo xhubier
exit
```

Se reconnecter en `xhubier`.

### 3. Installer Docker dans la VM

Procédure officielle Debian pour Docker CE :

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

Se déconnecter / reconnecter pour que le groupe `docker` prenne effet. Vérifier :

```bash
docker --version
docker compose version
docker run hello-world
```

### 4. Préparer le `/etc/hosts`

```bash
sudo nano /etc/hosts
```

Ajouter (remplacer `xhubier`) :

```
127.0.0.1 xhubier.42.fr
```

### 5. Créer les dossiers de données

Le sujet impose `/home/<login>/data/...` comme cible des bind-mounts.

```bash
mkdir -p /home/$USER/data/wordpress /home/$USER/data/mariadb
```

### 6. Récupérer le projet

```bash
cd /home/$USER
git clone <url-de-ton-repo> inception
cd inception
cp srcs/.env.example srcs/.env
nano srcs/.env   # mettre les vrais mots de passe + DOMAIN_NAME=xhubier.42.fr
```

### 7. Passer aux bind-mounts dans `docker-compose.yaml`

À l'éval, les volumes nommés sans `device` ne suffisent pas — il faut des bind-mounts explicites vers `/home/$USER/data/...`. Modifier le bloc `volumes:` de `srcs/docker-compose.yaml` :

```yaml
volumes:
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/xhubier/data/wordpress
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/xhubier/data/mariadb
```

### 8. Lancement

```bash
make up
docker ps         # vérifier que les 3 conteneurs sont Up
docker logs -f wordpress   # suivre l'install de WP
```

Quand `wordpress` finit son entrypoint (~30 s la première fois), ouvrir Firefox dans la VM sur `https://xhubier.42.fr/`. Accepter l'exception TLS (cert auto-signé).

### 9. Démo pour l'évaluateur

Points à pouvoir montrer :
- `docker ps` : 3 conteneurs `Up`, **port 443 seul exposé**.
- `docker network inspect srcs_inception` : les 3 services sont sur le même réseau.
- `docker volume inspect srcs_wordpress_data` : `device` pointe sur `/home/xhubier/data/wordpress`.
- Le site WP accessible en HTTPS.
- `curl -k -v https://xhubier.42.fr` montre `TLSv1.2` ou `TLSv1.3`.
- `make down` puis `make up` : les données WP/DB survivent (l'admin user existe toujours).
- Aucune image type `nginx:latest` utilisée (uniquement `debian:bookworm-slim` comme base).
- Aucun mot de passe en clair dans les Dockerfiles ni le compose.

---

## Développement local sur Windows (WSL2)

Pour éviter de bosser uniquement dans la VM, WSL2 + Ubuntu + Docker Desktop offre un équivalent fonctionnel :

1. PowerShell admin : `wsl --install -d Ubuntu`, reboot.
2. Installer Docker Desktop, activer WSL Integration → Ubuntu.
3. Cloner ce repo dans `~/projects/inception` côté WSL (pas dans `/mnt/c/`).
4. `mkdir -p ~/data/wordpress ~/data/mariadb`.
5. `sudo nano /etc/hosts` → `127.0.0.1 xhubier.42.fr`.
6. `cp srcs/.env.example srcs/.env`, éditer.
7. `make up`.

Pour accéder depuis Firefox/Chrome Windows : éditer aussi `C:\Windows\System32\drivers\etc\hosts` (admin) avec la même ligne.

## Pièges récurrents

- **Permissions `.sh`** depuis Windows : `find srcs -name "*.sh" -exec chmod +x {} +`.
- **Fin de ligne CRLF** : `sudo apt install dos2unix && find srcs -name "*.sh" -exec dos2unix {} +`. Ajouter `*.sh text eol=lf` dans un `.gitattributes`.
- **403 sur nginx** : `/var/www/html` est vide (entrypoint WP pas exécuté ou KO). `docker logs wordpress`.
- **WP ne se connecte pas à la DB** : vérifier que `WORDPRESS_DB_HOST=mariadb` (nom du service, pas `localhost`) et que les credentials matchent côté `MYSQL_*` et `WORDPRESS_DB_*`.
- **`make` cherche `docker-compose.yml`** : ton fichier est `.yaml`. Soit renommer, soit éditer le Makefile (`docker compose` v2 accepte les deux extensions).

Pourquoi exec à la fin de chaque entrypoint ? Pour remplacer le shell du script par le vrai daemon → daemon devient PID 1 → reçoit les signaux SIGTERM de docker stop proprement.
Pourquoi un réseau bridge custom et pas le default ? Avec un bridge nommé, les conteneurs se résolvent par nom de service via le DNS interne de Docker (ex. mariadb au lieu d'IP). Le default ne fait pas ça en mode legacy.
Pourquoi pas de port 80 ? Le sujet l'interdit. Seul 443 est exposé.
Pourquoi bind-mount et pas volume nommé "vide" ? Le sujet impose que les données soient dans /home/<login>/data/... côté hôte, pas dans le storage Docker.
Pourquoi le straggler restart: always ? Si mariadb crashe ou si la VM redémarre, Docker relance automatiquement. Indispensable pour la persistance.
Comment WP atteint MariaDB ? Via le DNS interne de Docker : WORDPRESS_DB_HOST=mariadb résout vers l'IP du conteneur mariadb sur le bridge inception.
Pourquoi pas d'image mysql:8 ou wordpress:latest ? Le sujet l'interdit : on doit construire les images soi-même à partir de Debian.
Comment le cert TLS est-il généré ? openssl req -x509 -nodes dans l'entrypoint nginx au premier démarrage. Auto-signé donc le navigateur le rejette par défaut (normal).