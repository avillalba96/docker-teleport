#!/bin/bash

# Función que se ejecuta al recibir la señal SIGINT (Ctrl+C)
function ctrl_c() {
    exit 0
}
trap ctrl_c INT

# Se solicita comando a ejecutar

read -p "Escriba el comando a ejecutar: " command

# Ejecutando el comando en cada nodo de los clusters
cluster_name=$(tsh clusters --format=json | jq '.[] | select(.status == "online") | .cluster_name' | sed 's/"//g')
for cluster in $cluster_name; do
    nodes_name=$(tsh ls node --cluster="$cluster" --format=json | jq '.[].spec.hostname' | sed 's/"//g' | grep -Ev "tp.*" | grep "docker")
    for node in $nodes_name; do
        echo "--------------------------"
        echo -e "Ejecutando comando sobre el \e[1;32m[$cluster]\e[0m en el nodo \e[0;31m[$node]\e[0m"
        echo ""
        tsh ssh --cluster=$cluster root@$node "$command"
    done
done

exit 0
