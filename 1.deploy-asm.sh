#!/bin/bash

if [ -z "$PROJECT" ]
then
echo "No PROJECT variable set, trying to use gcloud current project..."
export PROJECT=$(gcloud config get-value project)
echo "PROJECT set to $PROJECT"
fi

if [ -z "$LOCATION" ]
then
echo "No LOCATION variable set, using europe-west1..."
export LOCATION="europe-west1-c"
fi

if [ -z "$CLUSTERNAME" ]
then
echo "No CLUSTERNAME variable set, using 'asm-cluster'"
export CLUSTERNAME="asm-cluster"
fi

if [ -z "$GATEWAY_NAMESPACE" ]
then
echo "No GATEWAY_NAMESPACE variable set, using 'istio-gateway'"
export GATEWAY_NAMESPACE="istio-gateway"
fi

echo "Enabling APIs..."
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com

echo "Creating cluster..."
gcloud container clusters create $CLUSTERNAME \
    --project=$PROJECT \
    --zone=$LOCATION \
    --machine-type=e2-standard-4 \
    --num-nodes=2 \
    --workload-pool=$PROJECT.svc.id.goog

gcloud container clusters get-credentials $CLUSTERNAME \
--project=$PROJECT \
--zone=$LOCATION

kubectl config set-context $CLUSTERNAME

echo "Installing ASM..."
curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_1.13 > asmcli
chmod +x asmcli

sleep 5s

./asmcli install \
  --project_id $PROJECT \
  --cluster_name $CLUSTERNAME \
  --cluster_location $LOCATION \
  --fleet_id $PROJECT \
  --output_dir asmoutput \
  --enable_all \
  --ca mesh_ca

sleep 10s

echo "Deploying ASM Gateway..."
kubectl create namespace $GATEWAY_NAMESPACE

export REVISION=$(kubectl get deploy -n istio-system -l app=istiod -o \
  jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}')

kubectl label namespace $GATEWAY_NAMESPACE \
  istio.io/rev=$REVISION --overwrite

kubectl apply -n $GATEWAY_NAMESPACE \
  -f asmoutput/samples/gateways/istio-ingressgateway

echo "Deploying Online Boutique sample application..."
kubectl apply -f \
  asmoutput/samples/online-boutique/kubernetes-manifests/namespaces

for ns in ad cart checkout currency email frontend loadgenerator payment product-catalog recommendation shipping; do
  kubectl label namespace $ns istio.io/rev=$REVISION --overwrite
done;

kubectl apply -f \
 asmoutput/samples/online-boutique/kubernetes-manifests/deployments

kubectl apply -f \
 asmoutput/samples/online-boutique/kubernetes-manifests/services

kubectl apply -f \
 asmoutput/samples/online-boutique/istio-manifests/allow-egress-googleapis.yaml

kubectl apply -f \
    asmoutput/samples/online-boutique/istio-manifests/frontend-gateway.yaml

kubectl get service "istio-ingressgateway" \
    -n $GATEWAY_NAMESPACE