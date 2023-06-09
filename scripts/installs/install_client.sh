#!/bin/bash

# Verificamos si se instaló correctamente Teleport
if ! command -v teleport &>/dev/null; then
  echo ""
  echo "Teleport no se instaló correctamente."
  echo "Ejecutando comandos para eliminar la instalación anterior..."
  echo ""
  systemctl stop teleport.service
  pkill -f teleport
  rm -rf /var/lib/teleport
  rm -f /etc/teleport.yaml
  rm -f /usr/local/bin/teleport /usr/local/bin/tctl /usr/local/bin/tsh
  apt-get remove teleport -y
  apt-get purge teleport -y
  apt-get autoremove -y
  apt-get autoclean -y
  systemctl daemon-reload
  echo ""
else
  # Instalamos lsb-release si no están instalados
  if ! command -v lsb_release &>/dev/null; then
    apt-get install lsb-release -y
  fi

  cat <<EOF1 >/etc/teleport.yaml
version: v3
teleport:
  nodename: "HOST"
  advertise_ip: "IP_PARACONECTAR"
  data_dir: /var/lib/teleport
  join_params:
    token_name: "ID_TOKEN"
    method: token
  ca_pin: "CA_TOKEN"
  auth_server: SERVER:3025
  connection_limits:
      max_connections: 3
      max_users: 3
  log:
    output: stderr
    severity: INFO
    format:
      output: text
  diag_addr: ""
auth_service:
  enabled: "no"
ssh_service:
  enabled: "yes"
  port_forwarding: true
  pam:
    enabled: yes
  commands:
  - name: hostname
    command: [hostname]
    period: 1m0s
  - name: so
    command: ["/usr/bin/lsb_release", "-is", "-rs"]
    period: 1h0m0s
  - name: uptime
    command: ["/usr/bin/uptime", "-p"]
    period: 1m0s
  - name: teleport
    command: ["/usr/local/bin/teleport", "version"]
    period: 1h0m0s
proxy_service:
  enabled: "no"
  https_keypairs: []
  acme: {}
EOF1

  # Obtenemos variables
  HOST="$(hostname)"
  IP_PARACONECTAR=$(ip a s $(ip r | grep default | awk '{print $5}') | awk '/inet / {print $2}' | awk -F[/] '{print $1}')
  if [[ -z "${SERVER}" ]]; then
    read -p "Ingrese el valor para SERVER: " SERVER
  fi
  if [[ -z "${ID_TOKEN}" ]]; then
    read -p "Ingrese el valor para ID_TOKEN: " ID_TOKEN
  fi
  if [[ -z "${CA_TOKEN}" ]]; then
    read -p "Ingrese el valor para CA_TOKEN: " CA_TOKEN
  fi

  # Editar el archivo de configuración de Teleport
  sed -i 's/HOST/'"$HOST"'/g' /etc/teleport.yaml
  sed -i 's/IP_PARACONECTAR/'"$IP_PARACONECTAR"'/g' /etc/teleport.yaml
  sed -i 's/ID_TOKEN/'"$ID_TOKEN"'/g' /etc/teleport.yaml
  sed -i 's/CA_TOKEN/'"$CA_TOKEN"'/g' /etc/teleport.yaml
  sed -i 's/SERVER/'"$SERVER"'/g' /etc/teleport.yaml

read -p "¿Quiere cambiar el nodename del host (S/N)? " respuesta
if [[ "$respuesta" == "S" || "$respuesta" == "s" ]]; then
    read -p "Escriba el nombre de host a mostrar: " nombrehost
    sed -i "s/  nodename:.*/  nodename: $nombrehost/g" /etc/teleport.yaml
fi

read -p "¿Quiere agregar un label (env) personalizado (S/N)? " respuesta
if [[ "$respuesta" == "S" || "$respuesta" == "s" ]]; then
    read -p "Escriba la variable del label (env): " labelenv
    sed -i "/ssh_service:/a \  labels:\n    env: $labelenv" /etc/teleport.yaml
fi

  if command -v docker >/dev/null 2>&1; then
    sed -i 's/proxy_service:/  - name: docker\n    command: ["\/usr\/bin\/docker", "ps", "--filter", "status=running", "--format", "{{.Names}}"]\n    period: 1h0m0s\nproxy_service:/g' /etc/teleport.yaml
  fi

  systemctl enable teleport.service
  systemctl stop teleport.service
  sleep 3
  systemctl start teleport.service
  systemctl daemon-reload
fi

rm install_client.sh
