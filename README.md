# **IMPORTANTE**

## **Todo es una documentacion basica para el uso personal y traspaso de conocimiento, no tener en cuenta para produccion si eres un Tercero.**

------
------
------

## **TAREAS/NOTAS**

* Configurar S3
* Hacer que los roles los cree por defecto al levantar el docker
* Acomodar tutorial para los windows

## **Instalacion y inicializacion**

### GoTeleport esta disponible para Ubuntu16+ y Debian9+

* <https://github.com/gravitational/teleport/blob/master/build.assets/tooling/cmd/build-os-package-repos/runners.go#L42-L67>

### **Iniciar Servidor Teleport**

#### **Generando el docker**

* Hacemos las preparaciones necesarias para el funcionamiento del teleport

1. Configurar el sitio puerto 443(TCP) contra un proxy el cual redireccionara contra teleport:3080 incluso OBLIGATORIO el uso de certificado TLS/SSL(chain) ademas tener la opcion "Websockets Support" habilitada *(nosotros tambien configuramos las IPs desde la cual el proxy permitira el acceso)*.
2. Los demas puertos 3023:3025/TCP deben natear contra el servidior de teleport *(nosotros tambien configuramos las IPs desde la cual el proxy permitira el acceso)*.
3. En caso de no usar el servicio proxy-teleport, es necesario que los nodos tengan el acceso teleport:3025(TCP) y que el teleport pueda acceder a ellos node:3022(TCP)

* Generamos y damos de alta el docker teleport

```bash
prepare_docker.sh
```

* Generar usuarios genericos

```bash
#usuario ssh
docker exec teleport tctl users add usuario --roles=access,auditor,editor --logins=root
#usuario windows
docker exec teleport tctl users add usuario --roles=access,auditor,editor --windows-logins=Administrator
```

### **Agregar nodos**

<https://goteleport.com/docs/architecture/nodes/#cluster-state>

#### **Nodos contra un TELEPORT-HUB**

* Ejecutar el script de instalacion brindado por tu Teleport-HUB y asociarlo
* Al tener la conexion establecida, hacemos unas ediciones extras para nuestro nodo:

```bash
curl -s https://raw.githubusercontent.com/avillalba96/docker-teleport/main/scripts/installs/install_central.sh | bash
```

#### **Nodos contra un TELEPORT-CLIENT**

* Generar el token sobre el docker:

```bash
docker exec teleport tctl nodes add --ttl=1h
```

* Ejecutar el script y completar con la informacion que se solicita:

```bash
#https://goteleport.com/download/
#https://goteleport.com/docs/installation/
curl https://goteleport.com/static/install.sh | bash -s 12.1.1
curl -O https://raw.githubusercontent.com/avillalba96/docker-teleport/main/scripts/installs/install_client.sh && chmod +x install_client.sh && ./install_client.sh
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

<https://goteleport.com/docs/management/admin/trustedclusters/>

![cluster_trusted](imgs/cluster_trusted.png "cluster_trusted")

* Desde el Teleport-HUB en docker generar el token que se usara:

```bash
docker exec teleport tctl tokens add --type=trusted_cluster --ttl=15m
```

* Se requiere que Teleport-CLIENT tenga salida a internet contra los puertos del Teleport-HUB:3023-3025(TCP)
* Desde un Teleport-CLIENT, en el apartado "Trusted" apuntar la informacion contra el Teleport Principal *(editar las palabras "-CLIENT" y "tp.example-hub.com")*:

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

* Hay que generar un rol nuevo del lado del Teleport-HUB, para habilitar a los usuarios *(editar "-CLIENT" igual que el paso anterior)*

```bash
kind: role
metadata:
  name: cluster-CLIENT
version: v5
```

* Ademas hay que editar el rol "auditor" agregando lo siguiente como parametro extra:

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

### **Instalando tsh personalizado**

* Se deja un script personalizado para uso de <tsh> por consola *(esta adaptado para uso personal)*

```bash
sudo curl -o /usr/local/bin/tsh_console -L https://raw.githubusercontent.com/avillalba96/docker-teleport/main/scripts/others/tsh_console.sh && sudo chmod +x /usr/local/bin/tsh_console
```
