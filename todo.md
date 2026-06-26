docker system prune -af --volumes (avant eval)
wp-admin
wp-login.php

sur la VM 42, DATA_PATH=/home/jhubier/data impératif. Sur ton WSL actuel, DATA_PATH=/home/ghostwizer/data ne validera PAS ce point — il faut absolument adapter à l'éval

Reboot de la VM	⚠️	tester avant l'éval
54	Relancer docker compose après reboot	⚠️	make up après reboot doit tout remonter

docker ps (for port view)SELECT * FROM wp_comments\G



docker exec -it mariadb mariadb -uroot -proot_pwd
USE wordpress;
SHOW TABLES;
SELECT * FROM wordpress.wp_comments\G