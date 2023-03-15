#!/bin/bash

# Se cambia la variable aut_servers ya que se escribe de forma diferente en v12 comparado contra v10
IP=$(cat /etc/teleport.yaml | grep '\- \"' | awk -F[\ ] '{print $4}' | sed 's/"//g')
sed -i '/auth_servers/{n;d}' /etc/teleport.yaml
sed -i 's/auth_servers/auth_server/' /etc/teleport.yaml
sed -i "/auth_server:/s/$/ $IP/" /etc/teleport.yaml

# Se instala upgrade de teleport
apt-get install curl lsb-release -y
curl https://goteleport.com/static/install.sh | bash -s 12.1.1

rm "$0"
