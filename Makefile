NAME    := inception
COMPOSE := docker compose -f srcs/docker-compose.yaml
ENV     := srcs/.env

DATA_PATH := $(shell [ -f $(ENV) ] && grep -E '^DATA_PATH=' $(ENV) | cut -d= -f2- || echo /home/$$USER/data)

up:
	@mkdir -p $(DATA_PATH)/wordpress $(DATA_PATH)/mariadb
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v --rmi all --remove-orphans

fclean: clean

re: clean up

logs:
	$(COMPOSE) logs -f

.PHONY: up down clean fclean re logs
