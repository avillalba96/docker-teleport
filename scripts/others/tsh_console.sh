#!/bin/bash

VERSIONS="3.6"

# Verificar la existencia de tsh
if ! command -v tsh >/dev/null 2>&1; then
  clear
  echo "No posees instalado tsh, porfavor leer la documentacion."
  echo ""
fi

# Verificadno version del script
GITHUB_URL="https://raw.githubusercontent.com/avillalba96/docker-teleport/main/scripts/others/tsh_console.sh"
LOCAL_SCRIPT="/usr/local/bin/tsh_console"
REMOTE_SCRIPT="/tmp/tsh_console"

# Obtener la versión actual del script
VERSION_LOCAL=$(awk -F'"' '/VERSIONS=/{print $2}' "$LOCAL_SCRIPT" | head -n 1)

# Descargar la última versión del script de GitHub
wget -q "$GITHUB_URL" -O $REMOTE_SCRIPT

# Verificar si la descarga fue exitosa
if [ $? -eq 0 ]; then
  # Obtener la versión remota del script
  VERSION_REMOTE=$(awk -F'"' '/VERSIONS=/{print $2}' $REMOTE_SCRIPT | head -n 1)

  # Comparar la versión actual con la versión descargada
  if awk -v local="$VERSION_LOCAL" -v remote="$VERSION_REMOTE" 'BEGIN { if (local < remote) exit 0; exit 1; }'; then
    # Reemplazar el script actual con el nuevo
    clear
    printf "Se esta actualizando el \e[1;32m[tsh_console]\e[0m a la version \e[0;31m[$VERSION_REMOTE]\e[0m"
    sudo mv $REMOTE_SCRIPT "$LOCAL_SCRIPT"
    sudo chmod +x "$LOCAL_SCRIPT"
    sleep 5
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
  elif [[ -n "$(command -v brew)" ]]; then
    brew install $packages
  elif [[ -n "$(command -v dnf)" ]]; then
    sudo dnf install -y $packages
  else
    echo "No se pudo encontrar un gestor de paquetes válido."
    exit 1
  fi
}

# Verificar si los paquetes necesarios están instalados
packages=("dialog" "wget" "curl" "jq" "awk" "kubectl")
for package in "${packages[@]}"; do
  if ! command -v "$package" >/dev/null 2>&1; then
    echo "Instalando $package..."
    install_packages "$package"
    echo "Instalación de $package completada."
  fi
done

# Verificamos estar conectado a TSH
while ! tsh status > /dev/null 2>&1; do
  # Si el código de salida no es 0, ejecutar "tsh login"
  read -p "Ingrese la dirección del proxy Teleport: " proxy_address
  tsh login --proxy=$proxy_address
  # Esto sirve para el script del autocompletado
  tsh clusters --format=json | jq '.[] | select(.status == "online") | .cluster_name' | sed 's/"//g' > /tmp/tsh_clusters
  tsh status --format=json | jq '.active.logins[]' | sed 's/"//g' > /tmp/tsh_users
  tsh ls --cluster=$cluster_name --format=json | jq '.[].spec.hostname' | sed 's/\"//g' | grep -Ev 'tp.*' > /tmp/tsh_nodes
done

# Verificar si se proporcionaron los parámetros necesarios
if [ $# -eq 3 ]; then
  # Los parámetros se proporcionaron, ejecutar el comando tsh ssh
  clear
  tsh ssh --cluster=$1 $2@$3
  exit
fi

# Obtener la información de los clústeres
clusters=$(tsh clusters --format=json | jq '.[] | select(.status == "online") | .cluster_name' | sed 's/"//g')

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

function ssh_function() {
# Obtener la información de los nodos del clúster seleccionado
nodes=$(tsh ls --cluster="$cluster_name" --format=json | jq '.[].spec.hostname' | sed 's/"//g' | grep -Ev "tp.*")

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
logins=$(tsh status --format=json | jq '.active.logins[]' | sed 's/"//g')

# Crear un array con los nombres de los usuarios
user_names=($(echo "$logins" | tr ',' '\n' | tr -d ' '))

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
  clear
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
    clear
    tsh ssh --cluster="$cluster_name" -L "$local_port":localhost:"$remote_port" "$root_user@$node_name"
  fi

elif [ $option -eq 3 ]; then
  tsh login "$cluster_name" >/dev/null && tsh recording ls --format=json | jq -c '.[] | select(.server_hostname == "'"${node_name}"'") | {sid, participants, session_start, interactive}' | grep -v "false" | awk -F'[" ]' '{print $4" "$8" "$12}' >/tmp/logs.txt
  options=()
  while read -r line; do
    options+=("$line" "")
  done </tmp/logs.txt

  choice=$(dialog --clear --menu "Selecciona una grabacion:" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3)

  if [ ! -z "$choice" ]; then
    recording_id=$(echo "$choice" | awk '{print $1}')
    clear
    tsh play "$recording_id"
  fi
fi

}

function kube_function() {
# Obtener la información de los kubes del clúster seleccionado
kubes=$(tsh kube ls --cluster="$cluster_name" --format=json | jq '.[].kube_cluster_name' | sed 's/"//g')

# Verificar si hay kubes disponibles
kube_count=$(tsh kube ls --cluster="$cluster_name" --format=json | jq '.[].kube_cluster_name' | sed 's/"//g' | wc -l)

# Comprobar si hay kubes disponibles
if [ "$kube_count" -eq 0 ]; then
  echo "No hay kubes disponibles. Saliendo del script."
  exit 1
else
  # Crear un array con los nombres de los kubes
  kube_names=($(echo "$kubes" | tr -d '"' | sort))

  # Crear una lista con los nombres de los kubes
  kube_list=""
  for i in "${!kube_names[@]}"; do
    kube_list+="$((i + 1)) ${kube_names[i]} "
  done

  # Mostrar el menú y obtener la opción seleccionada
  option=$(dialog --clear --menu "Selecciona un kube:" 0 0 0 $kube_list 3>&1 1>&2 2>&3)
  if [ -z "$option" ]; then
    exit 1
  fi

  # Obtener el nombre del kube seleccionado
  kube_name=${kube_names[$((option - 1))]}

  # Conectando kube
  rm ~/.kube/config > /dev/null 2>&1
  ln -s ~/teleport-kubeconfig.yaml ~/.kube/config > /dev/null 2>&1
  export KUBECONFIG=${HOME?}/teleport-kubeconfig.yaml
  tsh kube login --cluster="$cluster_name" --all
  tsh kube login --cluster="$cluster_name" $kube_name
fi
}

# Mostrar pantalla de selección
CHOICE=$(dialog --stdout --title "Seleccionar una opción" --menu "¿Qué desea hacer?" 0 0 0 \
  "SSH" "Conectar por SSH" \
  "KUBE" "Conectar al KUBE")

# Ejecutar la función correspondiente
case $CHOICE in
  "SSH")
    ssh_function
    ;;
  "KUBE")
    kube_function
    ;;
  *)
    exit
    ;;
esac
