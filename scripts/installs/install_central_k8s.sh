#!/bin/bash

kubectl get configmap -n teleport teleport-agent -o yaml > teleport_configmap.yml


if ! grep -q "env" teleport_configmap.yml; then
  read -p "Escriba la variable del label (env): " labelenv
  sed -i "/teleport.internal/a \        env: $labelenv" teleport_configmap.yml
  CLIENT=$(grep "kube_cluster_name:" teleport_configmap.yml | head -n1 | awk '{print $2}' | cut -d'-' -f1)
  sed -i "/teleport.internal/a \        client: $CLIENT" teleport_configmap.yml

  sed -i '/resourceVersion:/d' teleport_configmap.yml
  kubectl apply -f teleport_configmap.yml
  kubectl delete pods -n teleport teleport-agent-0

  rm prod-cluster-values.yaml; rm teleport_configmap.yml
else
  echo "Verificar que se este exportando el configmap correcto, este parece ya poseer la variable (env)"
fi

rm install_central_k8s.sh
