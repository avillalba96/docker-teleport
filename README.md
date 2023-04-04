# **IMPORTANTE**

## **Todo es una documentacion basica para el uso personal y traspaso de conocimiento, no tener en cuenta para produccion si eres un Tercero.**

------
------
------

## **TAREAS/NOTAS**

* Configurar S3
* Acomodar tutorial para los windows

## **Instalacion y inicializacion**

### GoTeleport esta disponible para Ubuntu16+ y Debian9+

* <https://github.com/gravitational/teleport/blob/master/build.assets/tooling/cmd/build-os-package-repos/runners.go#L42-L67>

### **Iniciar Servidor Teleport**

#### **Generando el docker**

* Hacemos las preparaciones necesarias para el funcionamiento del teleport

1. Configurar el sitio puerto 443(TCP) contra un proxy el cual redireccionara contra teleport:3080 incluso OBLIGATORIO el uso de certificado TLS/SSL(chain) ademas tener la opcion "Websockets Support" habilitada *(nosotros tambien configuramos las IPs desde la cual el proxy permitira el acceso)*.
2. Los demas puertos 3023:3025/TCP deben natear contra el servidior de teleport *(nosotros tambien configuramos las IPs desde la cual el proxy permitira el acceso)*.
3. El docker que tenga el servicio del Teleport necesita tener salida a internet, ya que las cookies/etc las consulta contra internet
4. En caso de no usar el servicio proxy-teleport, es necesario que los nodos tengan el acceso teleport:3025(TCP) y que el teleport pueda acceder a ellos node:3022(TCP)

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

### **Agregar nodos/hosts**

#### **Nodos contra un TELEPORT-HUB *(Se usa para conectar contra un teleport a través de internet)***

* Ejecutar el script de instalacion brindado por tu Teleport-HUB y asociarlo
* Al tener la conexion establecida, hacemos unas ediciones extras para nuestro nodo:

```bash
curl -s https://raw.githubusercontent.com/avillalba96/docker-teleport/main/scripts/installs/install_central.sh | bash
```

#### **Nodos contra un TELEPORT-CLIENT *(Se usa para conectar contra un teleport local)***

* Generar el token sobre el docker:

```bash
docker exec teleport tctl nodes add --ttl=1h
```

* Ejecutar el script y completar con la informacion que se solicita:

```bash
if [ $(grep -c "VERSION_CODENAME" /etc/os-release) -eq 0 ]; then echo "FAIL: VERSION_CODENAME"; else curl https://goteleport.com/static/install.sh | bash -s 12.1.5; fi

curl -O https://raw.githubusercontent.com/avillalba96/docker-teleport/main/scripts/installs/install_client.sh && chmod +x install_client.sh && ./install_client.sh
```

### **Instalar descubrimiento de windows**

* <https://goteleport.com/docs/desktop-access/active-directory-manual/>
* <https://youtu.be/YvMqgcq0MTQ>

* Se requiere que el Servidor Teleport tenga acceso ldaps tcp/636 contra el equipo con ldap, ademas necesita acceso puerto rdp tcp/3389 contra todos los windows que descubra
* **Se siguieron los pasos tal cual en el docs/youtube, pero se dejan ejemplos/machete de lo que nosotros usamos**

```bash
#3/7
docker exec teleport tctl auth export --type=windows > user-ca.cer
#6/7
docker exec teleport tctl tokens add --type=windowsdesktop,node
```

* Se deja ejemplo de archivo "/etc/hosts"

```bash
# NPM - TELEPORT
X.X.X.X tp.example.com
X.X.X.X example.intranet ad.example.intranet
```

* Se deja ejemplo del archivo "/etc/teleport.yaml" en "examples/configs/teleport_server_example.yaml"

### **Agregar al Cluster**

![cluster_trusted](imgs/cluster_trusted.png "cluster_trusted")

* Se requiere que Teleport-CLIENT tenga salida a internet contra los puertos del Teleport-HUB:3023-3025(TCP)
* Hay que generar dos nuevos roles del lado de teleport Teleport-HUB y Teleport-CLIENT, ademas asignarlos a los usuarios correspondientes

```bash
cp examples/roles/rol_* teleport/config/
docker exec teleport tctl create -f /etc/teleport/rol_ssh-access.yaml
docker exec teleport tctl create -f /etc/teleport/rol_windows-desktop-admins.yaml
docker exec teleport tctl create -f /etc/teleport/rol_auditor.yaml
rm teleport/config/rol_*
docker exec teleport tctl users update usuario --set-roles=ssh-access,windows-desktop-admins,auditor,access,editor
```

* Desde el Teleport-HUB en docker generar el token que se usara en el siguiente paso:

```bash
docker exec teleport tctl tokens add --type=trusted_cluster --ttl=15m
```

* Editar las variables *"tp.example-hub.com"* y *"TOKEN_ID"* en el archivo "examples/roles/trusted_cluster.yaml"
* Desde un Teleport-CLIENT generar el rol trusted

```bash
cp examples/roles/trusted_* teleport/config/
docker exec teleport tctl create -f /etc/teleport/trusted_cluster.yaml
rm teleport/config/trusted_*
```

### **Instalando tsh personalizado**

* Se deja un script personalizado para uso de *"tsh"* por consola *(esta adaptado para uso personal)*

```bash
sudo curl -o /usr/local/bin/tsh_console -L https://raw.githubusercontent.com/avillalba96/docker-teleport/main/scripts/others/tsh_console.sh && sudo chmod +x /usr/local/bin/tsh_console
```
