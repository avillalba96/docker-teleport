#!/bin/bash

#!/bin/bash

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
for package in "${packages[@]}"
do
    if ! command -v "$package" >/dev/null 2>&1; then
        echo "Instalando $package..."
        install_packages "$package"
        echo "Instalación de $package completada."
    fi
done

# Obtener la información de los clústeres que comienzan con "tp.*"
clusters=$(tsh clusters | awk '$1 ~ /^tp\..*/ {print $1}')

# Crear un array con los nombres de los clústeres
cluster_names=($(echo "$clusters" | tr -d '"'))

# Crear una lista con los nombres de los clústeres
cluster_list=""
for i in "${!cluster_names[@]}"
do
    cluster_list+="$((i+1)) ${cluster_names[i]} "
done

# Mostrar el menú y obtener la opción seleccionada
option=$(dialog --clear --menu "Selecciona un clúster:" 0 0 0 $cluster_list 3>&1 1>&2 2>&3)
if [ -z "$option" ]; then
  exit 1
fi

# Obtener el nombre del clúster seleccionado
cluster_name=${cluster_names[$((option-1))]}

# Obtener la información de los nodos del clúster seleccionado
nodes=$(tsh ls node --cluster="$cluster_name" | grep -v "teleport=Teleport\|Node" | sed 's/--.*//g' | awk '{print $1}')

# Crear un array con los nombres de los nodos
node_names=($(echo "$nodes" | tr -d '"'))

# Crear una lista con los nombres de los nodos
node_list=""
for i in "${!node_names[@]}"
do
    node_list+="$((i+1)) ${node_names[i]} "
done

# Mostrar el menú y obtener la opción seleccionada
option=$(dialog --clear --menu "Selecciona un nodo:" 0 0 0 $node_list 3>&1 1>&2 2>&3)
if [ -z "$option" ]; then
  exit 1
fi

# Obtener el nombre del nodo seleccionado
node_name=${node_names[$((option-1))]}

# Obtener el listado de usuarios conectados
logins=$(tsh status | grep "Logins:" | sed 's/Logins:[[:space:]]*//')

# Crear un array con los nombres de los usuarios
user_names=($(echo "$logins" | tr ',' '\n' | tr -d ' ' | grep -v 'internal'))

# Crear una lista con los nombres de los usuarios
user_list=""
for i in "${!user_names[@]}"
do
    user_list+="$((i+1)) ${user_names[i]} "
done

# Mostrar el menú y obtener la opción seleccionada
option=$(dialog --clear --menu "Selecciona un usuario:" 0 0 0 $user_list 3>&1 1>&2 2>&3)
if [ -z "$option" ]; then
  exit 1
fi

# Obtener el nombre del usuario seleccionado
root_user=${user_names[$((option-1))]}

# Mostrar el menú y obtener la opción seleccionada
option=$(dialog --clear --menu "Selecciona una acción:" 0 0 0 1 "Conexion SSH" 2 "Generar TUNNEL" 3>&1 1>&2 2>&3)
if [ -z "$option" ]; then
  exit 1
elif [ $option -eq 1 ]; then
  tsh ssh --cluster="$cluster_name" "$root_user@$node_name"
elif [ $option -eq 2 ]; then
  # Solicitar al usuario el puerto local y el puerto destino
  local_port=$(dialog --clear --inputbox "Ingresa el puerto local:" 0 0 8889 3>&1 1>&2 2>&3)
  remote_port=$(dialog --clear --inputbox "Ingresa el puerto destino:" 0 0 8443 3>&1 1>&2 2>&3)

  # Ejecutar el comando de túnel con los puertos especificados por el usuario
  tsh ssh --cluster="$cluster_name" -L "$local_port":localhost:"$remote_port" "$root_user@$node_name"
fi
