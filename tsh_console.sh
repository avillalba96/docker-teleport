#!/bin/bash

VERSIONS="1.1"

# Verificadno version del script
GITHUB_URL="https://raw.githubusercontent.com/avillalba96/docker-teleport/main/tsh_console.sh"
LOCAL_SCRIPT="/usr/local/bin/tsh_console"
REMOTE_SCRIPT="/tmp/tsh_console"

# Obtener la versión actual del script
VERSION_LOCAL=$(grep -oP 'VERSIONS="\K[^"]+' "$LOCAL_SCRIPT" | head -n 1)
echo "$VERSION_LOCAL"

# Descargar la última versión del script de GitHub
wget --no-cache -q "$GITHUB_URL" -O $REMOTE_SCRIPT

# Verificar si la descarga fue exitosa
if [ $? -eq 0 ]; then
  # Obtener la versión remota del script
  VERSION_REMOTE=$(grep -oP 'VERSIONS="\K[^"]+' $REMOTE_SCRIPT | head -n 1)
  echo "$VERSION_REMOTE"

  # Comparar la versión actual con la versión descargada
  if [[ "$VERSION_LOCAL" != "$VERSION_REMOTE" ]]; then
    # Reemplazar el script actual con el nuevo
    sudo mv $REMOTE_SCRIPT "$LOCAL_SCRIPT"
    sudo chmod +x "$LOCAL_SCRIPT"
  fi
fi

# Función para instalar paquetes en diferentes sistemas operativos
install_packages() {
  packages="$1"
  # Comando para instalar paquetes en diferentes sistemas operativos
  if [[ -n "$(command -v apt-get)" ]]; then
    sudo apt-get update && sudo apt-get install -y $packages
  elif [[ -n "$(command -v yum)" ]]; then
    sudo yum install -y $packages
  elif [[ -n "$(command -v dnf)" ]]; then
    sudo dnf install -y $packages
  else
    echo "No se pudo encontrar un gestor de paquetes válido."
    exit 1
  fi
}

# Verificar si los paquetes necesarios están instalados
packages=("dialog")
for package in "${packages[@]}"; do
  if ! command -v "$package" >/dev/null 2>&1; then
    echo "Instalando $package..."
    install_packages "$package"
    echo "Instalación de $package completada."
  fi
done

# Verificar si se proporcionaron los parámetros necesarios
if [ $# -eq 3 ]; then
  # Los parámetros se proporcionaron, ejecutar el comando tsh ssh
  tsh ssh --cluster=tp.$1 $2@$3
  exit
fi

# Obtener la información de los clústeres que comienzan con "tp.*"
clusters=$(tsh clusters | awk '$1 ~ /^tp\..*/ {print $1}')

# Crear un array con los nombres de los clústeres
cluster_names=($(echo "$clusters" | tr -d '"' | sort))

# Crear una lista con los nombres de los clústeres
cluster_list=""
for i in "${!cluster_names[@]}"; do
  cluster_list+="$((i + 1)) ${cluster_names[i]} "
done

# Mostrar el menú y obtener la opción seleccionada
option=$(dialog --clear --menu "Selecciona un clúster:" 0 0 0 $cluster_list 3>&1 1>&2 2>&3)
if [ -z "$option" ]; then
  exit 1
fi

# Obtener el nombre del clúster seleccionado
cluster_name=${cluster_names[$((option - 1))]}

# Obtener la información de los nodos del clúster seleccionado
nodes=$(tsh ls node --cluster="$cluster_name" | grep -v "teleport=Teleport\|Node" | sed 's/--.*//g' | awk '{print $1}')

# Crear un array con los nombres de los nodos
node_names=($(echo "$nodes" | tr -d '"' | sort))

# Crear una lista con los nombres de los nodos
node_list=""
for i in "${!node_names[@]}"; do
  node_list+="$((i + 1)) ${node_names[i]} "
done

# Mostrar el menú y obtener la opción seleccionada
option=$(dialog --clear --menu "Selecciona un nodo:" 0 0 0 $node_list 3>&1 1>&2 2>&3)
if [ -z "$option" ]; then
  exit 1
fi

# Obtener el nombre del nodo seleccionado
node_name=${node_names[$((option - 1))]}

# Obtener el listado de usuarios conectados
logins=$(tsh status | grep "Logins:" | sed 's/Logins:[[:space:]]*//')

# Crear un array con los nombres de los usuarios
user_names=($(echo "$logins" | tr ',' '\n' | tr -d ' ' | grep -v 'internal'))

# Crear una lista con los nombres de los usuarios
user_list=""
for i in "${!user_names[@]}"; do
  user_list+="$((i + 1)) ${user_names[i]} "
done

# Mostrar el menú y obtener la opción seleccionada
option=$(dialog --clear --menu "Selecciona un usuario:" 0 0 0 $user_list 3>&1 1>&2 2>&3)
if [ -z "$option" ]; then
  exit 1
fi

# Obtener el nombre del usuario seleccionado
root_user=${user_names[$((option - 1))]}

# Mostrar el menú y obtener la opción seleccionada
option=$(dialog --clear --menu "Selecciona una acción:" 0 0 0 1 "Conexion SSH" 2 "Generar TUNNEL" 3 "Ver LOGS" 3>&1 1>&2 2>&3)
if [ -z "$option" ]; then
  exit 1
elif [ $option -eq 1 ]; then
  tsh ssh --cluster="$cluster_name" "$root_user@$node_name"
elif [ $option -eq 2 ]; then
  # Solicitar al usuario el puerto local y el puerto destino
  dialog --clear --form "Ingresa los puertos:" 0 0 0 \
    "Puerto local:" 1 1 "8889" 1 20 5 0 \
    "Puerto destino:" 2 1 "8443" 2 20 5 0 \
    2>/tmp/ports.txt

  # Saliendo en caso de cancelar
  exit_code=$?
  if [ $exit_code -eq 1 ] || [ $exit_code -eq 255 ]; then
    exit $exit_code
  else
    # Leer los valores ingresados por el usuario
    local_port=$(sed -n 1p /tmp/ports.txt)
    remote_port=$(sed -n 2p /tmp/ports.txt)

    # Ejecutar el comando de túnel con los puertos especificados por el usuario
    tsh ssh --cluster="$cluster_name" -L "$local_port":localhost:"$remote_port" "$root_user@$node_name"
  fi

elif [ $option -eq 3 ]; then
  tsh login "$cluster_name" >/dev/null && tsh recording ls | grep "$node_name" | awk '{print $1, $3, $5"-"$6"-"$7"-"$8}' | grep -v "ID" | sed 's/--.*//g' >/tmp/logs.txt
  options=()
  while read -r line; do
    options+=("$line" "")
  done </tmp/logs.txt

  choice=$(dialog --clear --menu "Selecciona una grabacion:" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3)

  if [ ! -z "$choice" ]; then
    recording_id=$(echo "$choice" | awk '{print $1}')
    tsh play "$recording_id"
  fi
fi
