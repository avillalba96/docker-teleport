#!/bin/bash

# Instalamos lsb-release si no están instalados
if ! command -v lsb_release &> /dev/null; then
    apt-get install lsb-release -y
fi

# Editando las lineas necesarias
sed -i '/diag_addr: ""/a \  connection_limits:\n    max_connections: 3\n    max_users: 3' /etc/teleport.yaml
sed -i '/ssh_service:/a \  port_forwarding: true' /etc/teleport.yaml
sed -i '/    period: 1m0s/a \  - name: so\n    command: ["/usr/bin/lsb_release", "-is", "-rs"]\n    period: 1h0m0s\n  - name: uptime\n    command: ["/usr/bin/uptime", "-p"]\n    period: 1m0s\n  - name: teleport\n    command: ["/usr/local/bin/teleport", "version"]\n    period: 1h0m0s' /etc/teleport.yaml

systemctl stop teleport.service; sleep 3; systemctl start teleport.service; systemctl daemon-reload

rm install_central.sh
