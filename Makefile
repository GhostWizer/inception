NAME := inception
COMPOSE := docker compose -f srcs/docker-compose.yaml

up:
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
