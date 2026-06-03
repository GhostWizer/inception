NAME := inception

up:
	docker compose -f srcs/docker-compose.yml up -d --build

down:
	docker compose -f srcs/docker-compose.yml down

clean:
	docker compose -f srcs/docker-compose.yml down -v --rmi all --remove-orphans

fclean: clean

re: clean up

.PHONY: up down clean fclean re
