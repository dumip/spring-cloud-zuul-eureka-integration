#!/bin/bash

az login
az group create --name=duf-k8s-demo --location=westeurope

# create the azure container registry
az acr create --resource-group duf-k8s-demo --location westeurope \
 --name dufregistry --sku Basic

 # set the default name for Azure Container Registry, otherwise you will need to specify the name in "az acr login"
az configure --defaults acr=dufregistry
az acr login

# create the virtual network to which the k8s cluster is assigned
az network vnet create \
  --name dufk8svnet \
  --resource-group duf-k8s-demo \
  --subnet-name default

# show the created vnet
VNET_ID=`az network vnet subnet show -g duf-k8s-demo -n default --vnet-name dufk8svnet --query id`

# create the  k8s cluster
az aks create --resource-group=duf-k8s-demo --name=duf-k8s-hello-cluster \
 --dns-name-prefix=dufk8shello \
 --generate-ssh-keys \
 --network-plugin azure \
 --service-cidr=10.1.0.0/16 \
 --dns-service-ip=10.1.0.10 \
 --vnet-subnet-id=${VNET_ID}
# /subscriptions/cda62bf0-9873-424e-9a38-4d15663c4317/resourceGroups/duf-k8s-demo/providers/Microsoft.Network/virtualNetworks/dufk8svnet/subnets/default

# ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDI3Qg/p0CxbBTLtxwG9IvdXKPSJgfbhENjrzNeUuldTlXpKmjgucnBXS+UraqRLjkhpCVz1uyK2Z0X6y0BwnCVRd9tdi1KaOqpqPcMcf00ydl6S2n5COf666eleQk1fNN02SLaUxulNwiKhyG9wNYebHKHz31ZjTV4PPei37yBM8Qp4veOQyk6prsfC9rNYGsWyBFeN4tkOO2/wUFG6nqm0yFZLh6a8j0XM19Shq4hMDN1XVpFgKC4a8COxM3J2LmQxYLKd/fVDDFBUkjKMEmat+dPwI98AMcka+IOoTVAepTLp/yCY2/KPaeUdR/E/9ACt1hL9VzzGqOcQ6G+cuqf dumitrupascu@Dumitrus-Mac-mini.local

# Get the id of the service principal configured for AKS
CLIENT_ID=$(az aks show -g duf-k8s-demo -n duf-k8s-hello-cluster --query "servicePrincipalProfile.clientId" --output tsv)

# Get the ACR registry resource id
ACR_ID=$(az acr show -g duf-k8s-demo -n dufregistry --query "id" --output tsv)

# Create role assignment
az role assignment create --assignee $CLIENT_ID --role acrpull --scope $ACR_ID

# Install kubectl using the Azure CLI (one time only run)
az aks install-cli

# Download the cluster configuration information so you can manage your cluster from the Kubernetes web interface and kubectl
az aks get-credentials --resource-group=duf-k8s-demo --name=duf-k8s-hello-cluster

# Deploy eureka-server container
kubectl run eureka-server --image=dufregistry.azurecr.io/eureka-server:latest
kubectl expose deployment eureka-server --type=LoadBalancer --port=8761 --target-port=8761

# Get the ip of the LB
MY_IP=`kubectl get services -o jsonpath={.items[*].status.loadBalancer.ingress[0].ip} --namespace=default`

# Deploy eureka-client container
kubectl run eureka-client --image=dufregistry.azurecr.io/eureka-client:latest
#kubectl expose deployment eureka-client --type=LoadBalancer --port=8081 --target-port=8081

# Deploy zuul-service container
kubectl run zuul-server --image=dufregistry.azurecr.io/zuul-server:latest
kubectl expose deployment zuul-server --type=LoadBalancer --port=8762 --target-port=8762

# Just to view the Kubernetes management gui
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
az aks browse --resource-group=duf-k8s-demo --name=duf-k8s-hello-cluster



