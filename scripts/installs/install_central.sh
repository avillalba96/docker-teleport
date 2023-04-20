#!/bin/bash

POTENTE=""

read -p "¿Desea ejecutar los comandos con 'sudo' (S/N)? " respuesta
if [[ "$respuesta" == "S" || "$respuesta" == "s" ]]; then
    POTENTE="sudo"
fi

# Instalamos lsb-release si no están instalados
if ! command -v lsb_release &>/dev/null; then
    $POTENTE apt-get install lsb-release -y
fi

# Editando las lineas necesarias
$POTENTE sed -i '/diag_addr: ""/a \  connection_limits:\n    max_connections: 3\n    max_users: 3' /etc/teleport.yaml
$POTENTE sed -i '/ssh_service:/a \  port_forwarding: true\n  pam:\n    enabled: yes' /etc/teleport.yaml
$POTENTE sed -i '/    period: 1m0s/a \  - name: so\n    command: ["/usr/bin/lsb_release", "-is", "-rs"]\n    period: 1h0m0s\n  - name: uptime\n    command: ["/usr/bin/uptime", "-p"]\n    period: 1m0s\n  - name: teleport\n    command: ["/usr/local/bin/teleport", "version"]\n    period: 1h0m0s' /etc/teleport.yaml

read -p "¿Quiere cambiar el nodename del host (S/N)? " respuesta
if [[ "$respuesta" == "S" || "$respuesta" == "s" ]]; then
    read -p "Escriba el nombre de host a mostrar: " nombrehost
    $POTENTE sed -i "s/  nodename:.*/  nodename: $nombrehost/g" /etc/teleport.yaml
fi

if command -v docker >/dev/null 2>&1; then
    $POTENTE sed -i 's/proxy_service:/  - name: docker\n    command: ["\/usr\/bin\/docker", "ps", "--filter", "status=running", "--format", "{{.Names}}"]\n    period: 1h0m0s\nproxy_service:/g' /etc/teleport.yaml
fi

$POTENTE systemctl stop teleport.service
$POTENTE sleep 3
$POTENTE systemctl start teleport.service
$POTENTE systemctl daemon-reload
