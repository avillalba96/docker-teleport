#!/bin/bash

### PREPARANDO EL DOMINIO ###
url="$(hostname -d)"
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

grep -rl 'example.com' $dir | xargs sed -i "s/example.com/$url/g"

### PREPARANDO DOCKER ###
docker-compose -f docker-compose-init.yml up && docker rm teleport-configure

### INICIANDO DOCKER ###
cp teleport_server_example.yaml teleport/config/teleport.yaml
docker-compose -f docker-compose.yml --compatibility up -d; docker-compose logs -ft --tail=35
