#!/bin/bash                           # Tells the system to run this script using the Bash shell

# Color codes for formatting
RED='\e[1;31m'                        # Define red color for text output
GREEN='\e[1;32m'                      # Define green color for success messages
YELLOW='\e[1;33m'                     # Define yellow color for warnings
BLUE='\e[1;34m'                       # Define blue color for information messages
MAGENTA='\e[1;35m'                    # Define magenta color for headers
CYAN='\e[1;36m'                       # Define cyan color for highlights
WHITE='\e[1;37m'                      # Define white color
NC='\e[0m'                            # Reset color back to default (No Color)

# Function to display spinner animation while a process runs
spinner() {
    local pid=$1                      # Store the process ID passed to the function
    local delay=0.1                   # Delay between spinner frames
    local spinstr='|/-\'              # Characters used for spinner animation

    # Loop while the process with given PID is running
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}       # Remove first character from spinner string
        printf " [%c]  " "$spinstr"   # Print spinner character
        local spinstr=$temp${spinstr%"$temp"} # Rotate spinner characters
        sleep $delay                  # Pause briefly to create animation effect
        printf "\b\b\b\b\b\b"         # Move cursor back to overwrite spinner
    done

    printf "    \b\b\b\b"             # Clear spinner after process finishes
}

# Function to print section headers in a formatted box
print_header() {
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}" # Top border
    echo -e "${MAGENTA}║${NC} ${CYAN}$1${NC} ${MAGENTA}║${NC}"                                           # Header text
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}" # Bottom border
}

# Function to print success message
print_success() {
    echo -e "${GREEN}✅ $1${NC}"      # Print message in green with check mark
}

# Function to print error message
print_error() {
    echo -e "${RED}❌ $1${NC}"        # Print message in red with cross symbol
}

# Function to print informational message
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"      # Print message in blue
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"     # Print warning message in yellow
}

(sleep 3) & spinner $!            # Run sleep for 3 seconds and show spinner animation
echo -e "${GREEN}✅ Subscribed! Thank you for your support!${NC}" # Confirmation message

# Fetch zone and region from Google Cloud configuration
print_header "Fetching Google Cloud Configuration" # Print section header

print_info "Getting zone, region, and project details..." # Inform user

ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null) # Get default compute zone

REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null) # Get default region

PROJECT_ID=$(gcloud config get-value project 2>/dev/null) # Get current Google Cloud project ID

# Check if values were successfully retrieved
if [ -z "$ZONE" ] || [ -z "$REGION" ] || [ -z "$PROJECT_ID" ]; then
    print_error "Failed to get Google Cloud configuration. Please check your gcloud setup." # Show error
    exit 1                   # Stop script execution
fi

print_success "Zone: $ZONE"         # Print detected zone
print_success "Region: $REGION"     # Print detected region
print_success "Project ID: $PROJECT_ID" # Print project ID

# Set compute zone for future gcloud commands
print_info "Setting compute zone..."
gcloud config set compute/zone $ZONE  # Apply zone configuration

# Copy Kubernetes lab files from Google Cloud Storage
print_header "Setting up Kubernetes Resources"
print_info "Copying Kubernetes configuration files..."

gcloud storage cp -r gs://spls/gsp053/kubernetes . &  # Copy Kubernetes config files
spinner $!                                           # Show spinner while copying

cd kubernetes                                         # Enter downloaded folder

# Create Google Kubernetes Engine (GKE) cluster
print_header "Creating GKE Cluster"
print_info "Creating Kubernetes cluster with 3 nodes..."

gcloud container clusters create bootcamp \           # Create cluster named bootcamp
  --machine-type e2-small \                           # Use e2-small machine type
  --num-nodes 3 \                                     # Create 3 worker nodes
  --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw" & # Set access scopes

spinner $!                                            # Show spinner during cluster creation
print_success "GKE cluster created successfully!"     # Confirm cluster creation

# TASK 2 - Deploy application
print_header "TASK 2: Deploying Fortune App (Blue)"

print_info "Creating deployment and service..."

kubectl create -f deployments/fortune-app-blue.yaml & # Deploy blue version of app
spinner $!

kubectl create -f services/fortune-app.yaml &         # Create Kubernetes service
spinner $!

# Scale deployment to 5 replicas
print_info "Scaling deployment to 5 replicas..."

kubectl scale deployment fortune-app-blue --replicas=5 & # Increase pods to 5
spinner $!

COUNT=$(kubectl get pods | grep fortune-app-blue | wc -l | tr -d ' ') # Count running pods
print_success "Current replicas: $COUNT" # Display replica count

# Scale deployment down to 3 replicas
print_info "Scaling deployment to 3 replicas..."

kubectl scale deployment fortune-app-blue --replicas=3 & # Reduce pods to 3
spinner $!

COUNT=$(kubectl get pods | grep fortune-app-blue | wc -l | tr -d ' ') # Count again
print_success "Current replicas: $COUNT"

# TASK 3 - Canary Deployment
print_header "TASK 3: Canary Deployment"

echo -e "${YELLOW}🎯 This task will perform a canary deployment strategy${NC}" # Explain next task

echo -ne "${CYAN}? Do you want to continue with Task 3? ${NC}[${GREEN}Y${NC}/${RED}N${NC}]: " # Ask user
read -r CONFIRM   # Read user input

# If user says no, stop script
if [[ "$CONFIRM" != "Y" && "$CONFIRM" != "y" ]]; then
    print_warning "Task 3 aborted by user."
    exit 0
fi

print_info "Updating container image to version 2.0.0..."

kubectl set image deployment/fortune-app-blue fortune-app=$REGION-docker.pkg.dev/qwiklabs-resources/spl-lab-apps/fortune-service:2.0.0 & # Update container image
spinner $!

print_info "Setting environment variable..."

kubectl set env deployment/fortune-app-blue APP_VERSION=2.0.0 & # Set environment variable
spinner $!

print_info "Creating canary deployment..."

kubectl create -f deployments/fortune-app-canary.yaml & # Deploy canary version
spinner $!

print_success "Canary deployment created successfully!"

# TASK 5 - Blue-Green Deployment
print_header "TASK 5: Blue-Green Deployment"

print_info "Setting up blue service..."

kubectl apply -f services/fortune-app-blue-service.yaml & # Apply blue service
spinner $!

print_info "Creating green deployment..."

kubectl create -f deployments/fortune-app-green.yaml & # Deploy green version
spinner $!

print_info "Setting up green service..."

kubectl apply -f services/fortune-app-green-service.yaml & # Create green service
spinner $!

print_info "Updating blue service..."

kubectl apply -f services/fortune-app-blue-service.yaml & # Update blue service routing
spinner $!

print_success "Blue-Green deployment setup completed!"

# Final summary
print_header "Lab Completion Status"

echo -e "${GREEN}🎉 All tasks completed successfully!${NC}" # Final success message

echo -e "${CYAN}📊 Current deployments:${NC}"
kubectl get deployments          # Show all deployments

echo -e "\n${CYAN}🌐 Current services:${NC}"
kubectl get services             # Show all services

echo -e "\n${CYAN}🐳 Current pods:${NC}"
kubectl get pods                 # Show running pods

echo -e "\n${MAGENTA}=================================================${NC}"
