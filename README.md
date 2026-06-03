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

## Ce que j'ai posé

- un `docker-compose.yml` avec les 3 services centraux;
- un `Makefile` pour lancer, arrêter et nettoyer l'infra;
- les dossiers `conf/` et `tools/` par service;
- une base Nginx avec TLS;
- une base WordPress en PHP-FPM;
- une base MariaDB avec sa config minimale.

## Vérification

La validation Docker n'a pas pu être exécutée ici, car Docker n'est pas installé dans cet environnement.
J'ai quand même confirmé statiquement que tous les fichiers référencés existent.

## Suite logique

La prochaine étape consiste à rendre chaque service réellement conforme au sujet:

1. installer WordPress dans le conteneur dédié;
2. écrire l'initialisation MariaDB;
3. finaliser la config Nginx avec FastCGI;
4. ajouter les scripts d'entrée robustes et idempotents.
