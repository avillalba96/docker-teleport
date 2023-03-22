# **IMPORTANTE**

## **Todo es una documentacion basica para el uso personal y traspaso de conocimiento, no tener en cuenta para produccion si eres un Tercero.**

------
------
------

## **TAREAS/NOTAS**

* Configurar S3
* Hacer que los roles los cree por defecto al levantar el docker
* read y docker-compose con version 12.1.1 con .env de ser posible

## **Instalacion y inicializacion**

### GoTeleport esta disponible para Ubuntu16+ y Debian9+

* <https://github.com/gravitational/teleport/blob/master/build.assets/tooling/cmd/build-os-package-repos/runners.go#L42-L67>

### **Iniciar Servidor Teleport**

* Ejecutar el siguiente script para iniciar el docker

```bash
prepare_docker.sh
```

* Hay que configurar SSL/TLS sobre el sitio *(puede variar segun como lo deseen, en nuestro caso usamos nginxproxymanager)*:

1. Configurar en nginx para que el puerto 443 redireccione contra el 3080 del docker, es OBLIGATORIO el uso de certificado TLS(CA+CHAIN+KEY) incluso tener la opcion "Websockets Support" habilitada.
2. Todos los demas puertos expuestos en docker tienen que ser accesible por NAT directamente contra el docker

* Generar usuario

```bash
#usuario ssh
docker exec teleport tctl users add usuario --roles=access,auditor,editor --logins=root
#usuario windows
docker exec teleport tctl users add usuario --roles=access,auditor,editor --windows-logins=Administrator
```

### **Agregar nodos**

<https://goteleport.com/docs/architecture/nodes/#cluster-state>

#### **Nodos contra un TELEPORT-HUB**

*. Ejecutar el script de instalacion brindado por tu Teleport-HUB y asociarlo
*. Al tener la conexion establecidas, hacemos uan ediciones extras para nuestro nodo:

```bash
curl -s https://raw.githubusercontent.com/avillalba96/docker-teleport/main/install_central.sh | bash
```

#### **Nodos contra un TELEPORT-CLIENT**

*. Generar el token sobre el docker:

```bash
docker exec teleport tctl nodes add --ttl=1h
```

*. Ejecutar el script y completar con la informacion que se solicita:

```bash
#https://goteleport.com/download/
#https://goteleport.com/docs/installation/
curl https://goteleport.com/static/install.sh | bash -s 12.1.1
curl -O https://raw.githubusercontent.com/avillalba96/docker-teleport/main/install_client.sh && chmod +x install_client.sh && ./install_client.sh
```

### **Instalar descubrimiento de windows**

* <https://goteleport.com/docs/desktop-access/active-directory-manual/>
* <https://youtu.be/YvMqgcq0MTQ>

* Se requiere que el Servidor Teleport tenga acceso ldaps tcp/636 contra el equipo con ldap, ademas necesita acceso puerto rdp tcp/3389 contra todos los windows que descubra
* Generar el token ya que se necesitara *(incluso se necesita el CA_PIN)*:

```bash
docker exec teleport tctl tokens add --type=windowsdesktop,node
```

* Se deja ejemplo de archivo "/etc/hosts"

```bash
# PROXY TSH RDP
X.X.X.X tp.example.com
X.X.X.X example.intranet win16-ad.example.intranet
```

* Se deja ejemplo de archivo "/etc/teleport.yaml"

```bash
# TEXTO
```

### **Agregar al Cluster**

* La conexion es Cliente --> Servidor.

![cluster_trusted](imgs/cluster_trusted.png "cluster_trusted")

* Desde el Teleport-HUB en docker generar el token que se usara:

```bash
docker exec teleport tctl tokens add --type=trusted_cluster --ttl=15m
```

* Desde un Teleport-CLIENT, en el apartado "Trusted" apuntar la informacion contra el Teleport Principal:

```bash
kind: trusted_cluster
metadata:
  name: tp.example-hub.com
spec:
  enabled: true
  role_map:
  - local:
    - access
    remote: cluster-CLIENT
  token: TOKEN_ID
  tunnel_addr: tp.example-hub.com:3024
  web_proxy_addr: tp.example-hub.com:443
version: v2
```

* Hay que generar un rol nuevo del lado del Teleport-HUB, para habilitar a los usuarios *(teniendo en cuenta la variable CLIENT)*

```bash
kind: role
metadata:
  name: cluster-CLIENT
version: v5
```

* Ademas hay que editar el rol "auditor" agregando lo siguiente como parametro extra:
* <https://goteleport.com/docs/setup/reference/config/>

```bash
spec:
  allow:
    join_sessions:
    - kinds:
      - k8s
      - ssh
      modes:
      - moderator
      - observer
      - peer
      name: Auditor oversight
      roles:
      - auditor
```

### **Borrando Nodos/Clusters**

<https://goteleport.com/docs/management/admin/trustedclusters/>

```bash
docker exec teleport tctl get nodes
docker exec teleport tctl rm nodes/xxxxxxx-xxxxxxxx-xxxxxxxxx

docker exec teleport tctl get rc
docker exec teleport tctl rm rc/tp.example2.com
```
