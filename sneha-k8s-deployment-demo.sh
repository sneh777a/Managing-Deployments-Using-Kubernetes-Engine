#!/bin/bash

# ==========================================================
# Kubernetes Deployment Strategies Demo
# Author: Sneha Ghosh
# Description:
# Demonstrates Rolling Update, Scaling, and Canary Deployment
# on Google Kubernetes Engine (GKE)
# ==========================================================

AUTHOR="Sneha Ghosh"

echo "=================================================="
echo " Kubernetes Deployment Strategies Demo"
echo " Created by: $AUTHOR"
echo "=================================================="
echo ""

# Ask user for inputs (with defaults)

read -p "Enter Cluster Name [default: demo-cluster]: " CLUSTER
CLUSTER=${CLUSTER:-demo-cluster}

read -p "Enter Zone (example: us-central1-a) [default: us-central1-a]: " ZONE
ZONE=${ZONE:-us-central1-a}

read -p "Enter Application Name [default: demo-app]: " APP_NAME
APP_NAME=${APP_NAME:-demo-app}

echo ""
echo "Using Configuration:"
echo "Cluster Name: $CLUSTER"
echo "Zone: $ZONE"
echo "App Name: $APP_NAME"
echo ""

# Step 1: Create GKE Cluster
echo "Step 1: Creating GKE cluster..."
gcloud container clusters create $CLUSTER \
  --zone $ZONE \
  --machine-type e2-small \
  --num-nodes 3

# Get credentials
gcloud container clusters get-credentials $CLUSTER --zone $ZONE

echo "Cluster created successfully."
echo ""

# Step 2: Deploy Version 1
echo "Step 2: Deploying Version 1 (nginx:1.25)..."
kubectl create deployment $APP_NAME --image=nginx:1.25
kubectl expose deployment $APP_NAME --type=LoadBalancer --port=80

echo "Application deployed and exposed."
echo ""

# Step 3: Scaling Demonstration
echo "Step 3: Scaling application to 5 replicas..."
kubectl scale deployment $APP_NAME --replicas=5
sleep 10

echo "Scaling back to 3 replicas..."
kubectl scale deployment $APP_NAME --replicas=3
echo "Scaling demonstration completed."
echo ""

# Step 4: Rolling Update
echo "Step 4: Performing Rolling Update to Version 2 (nginx:1.26)..."
kubectl set image deployment/$APP_NAME nginx=nginx:1.26
kubectl rollout status deployment/$APP_NAME

echo "Rolling update completed successfully."
echo ""

# Step 5: Canary Deployment
echo "Step 5: Creating Canary Deployment (1 replica running v2)..."
kubectl create deployment ${APP_NAME}-canary \
  --image=nginx:1.26 \
  --replicas=1

echo "Canary deployment created."
echo ""

echo "=================================================="
echo " Demo Completed Successfully!"
echo " Script Author: $AUTHOR"
echo "=================================================="
