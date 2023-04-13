#!/bin/bash

### PREPARANDO EL DOMINIO ###
url="$(hostname -d)"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

read -p "¿Quiere utilizar el dominio $url (S/N)? " respuesta
if [[ "$respuesta" == "S" || "$respuesta" == "s" ]]; then
    grep -rl 'example.com' $dir | grep -vE "prepare_docker.sh|README.md" | xargs sed -i "s/example.com/$url/g"
else
    read -p "Escriba el dominio a utilizar (ignorando el subdominio tp.): " url
    grep -rl 'example.com' $dir | grep -vE "prepare_docker.sh|README.md" | xargs sed -i "s/example.com/$url/g"
fi

### PREPARANDO DOCKER ###
docker-compose -f docker-compose-init.yml up && docker-compose -f docker-compose-init.yml rm -f teleport-configure

### INICIANDO DOCKER ###
docker network create npm-network
cp examples/configs/teleport_server_example.yaml teleport/config/teleport.yaml
read -p "¿Quiere iniciar Teleport+Nginx (S/N)? " respuesta
if [[ "$respuesta" == "S" || "$respuesta" == "s" ]]; then
    read -p "Ingrese la contraseña para MYSQL_PASS: " password01
    read -p "Ingrese la contraseña para ROOT_PASSWORD: " password02
    sed -i "s/password01/$password01/g" .env
    sed -i "s/password02/$password02/g" .env
    docker-compose -f docker-compose.yml --profile full --compatibility up -d
    echo ""
    echo "Acceso NGINX:"
    echo ""
    echo "http://127.0.0.1:81"
    echo "Email:    admin@example.com"
    echo "Password: changeme"
    echo ""
else
    docker-compose -f docker-compose.yml --profile teleport --compatibility up -d
fi
#docker-compose -f docker-compose.yml --profile teleport down -v
#docker-compose logs -ft --tail=35 teleport
