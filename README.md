# Inception

Base de projet pour 42 Inception.

## Objectif du projet

Inception sert à construire une petite infrastructure avec Docker.
L'idée n'est pas seulement de faire tourner WordPress, mais de comprendre comment séparer les responsabilités:

- Nginx joue le rôle de reverse proxy et termine le HTTPS;
- WordPress fournit l'application PHP;
- MariaDB stocke les données;
- des volumes conservent les données entre les redémarrages;
- un réseau privé relie les services entre eux;
- `docker-compose` orchestre l'ensemble;
- un `Makefile` simplifie les commandes de base.

## Ce qu'il faut maîtriser

1. Une image Docker est un modèle construit par un `Dockerfile`.
2. Un conteneur est une instance lancée à partir d'une image.
3. Un volume garde les données même si le conteneur est supprimé.
4. Un réseau Docker isole les services tout en leur permettant de communiquer.
5. `docker-compose` décrit la topologie du projet.
6. Chaque service doit rester focalisé sur un seul rôle.

## Architecture visée

Le flux normal est:

`client -> Nginx -> WordPress/PHP-FPM -> MariaDB`

Nginx écoute sur le port 443.
WordPress ne doit pas embarquer un serveur web séparé.
MariaDB ne doit pas être exposé directement sur l'hôte.

## Arborescence du projet

```text
.
├── Makefile
├── README.md
└── srcs
	├── .env
	├── .env.example
	├── docker-compose.yml
	└── requirements
		├── mariadb
		│   ├── Dockerfile
		│   ├── conf
		│   │   └── my.cnf
		│   └── tools
		│       └── entrypoint.sh
		├── nginx
		│   ├── Dockerfile
		│   ├── conf
		│   │   └── nginx.conf
		│   └── tools
		│       └── entrypoint.sh
		└── wordpress
			├── Dockerfile
			├── conf
			└── tools
				└── entrypoint.sh
```


**rapatries ton code à chaque fois que tu travailles dessus.**

sudo apt update
sudo apt install -y docker.io docker-compose-v2 make git
sudo usermod -aG docker $USER
# se reconnecter pour que le groupe prenne effet
mkdir -p /home/$USER/data/wordpress /home/$USER/data/mariadb