#!/bin/bash

if [ -z "$PROJECT" ]
then
echo "No PROJECT variable set"
exit
fi

if [ -z "$LOCATION" ]
then
echo "No LOCATION variable set"
exit
fi

if [ -z "$CLUSTERNAME" ]
then
echo "No CLUSTERNAME variable set"
exit
fi

if [ -z "$GATEWAY_NAMESPACE" ]
then
echo "No GATEWAY_NAMESPACE variable set"
exit
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