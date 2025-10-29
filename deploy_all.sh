!/bin/bash
set -e

# Disable path conversion on Windows Git Bash
export MSYS_NO_PATHCONV=1

echo "🚀 Starting complete infrastructure and application deployment..."
echo ""
# --- AZ LOGIN CHECK ---
echo "⚙️ Checking Azure CLI login status..."
az account show > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "❌ You are not logged in to Azure CLI."
  echo "Please run 'az login' and authenticate before running this script."
  exit 1
fi
echo "✅ Azure CLI logged in."

export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "✅ ARM_SUBSCRIPTION_ID set to: $ARM_SUBSCRIPTION_ID"

# --- DOCKER RUNNING CHECK ---
echo "🐳 Checking Docker installation and daemon status..."
# 1. Check if 'docker' command is available
if ! command -v docker &> /dev/null
then
    echo "❌ Docker command not found."
    echo "Please ensure Docker is installed and added to your system's PATH."
    echo "For installation instructions, visit: https://docs.docker.com/get-docker/"
    exit 1
fi
echo "✅ Docker command found."
# 2. Check if Docker daemon is running
if ! docker info &> /dev/null
then
    echo "❌ Docker daemon is not running or not accessible."
    echo "Please start Docker Desktop/daemon before running this script."
    exit 1
fi
echo "✅ Docker daemon is running."

# Step 1: Deploy Infrastructure (terraform-01)
echo "📋 Step 1: Deploying Infrastructure..."
cd terraform/01-infrastructure
terraform init
terraform plan -out=infrastructure.tfplan
terraform apply -auto-approve infrastructure.tfplan
cd ../..
echo "✅ Infrastructure deployed successfully!"
echo ""

# Step 2: Build and Push Dashboard Image
echo "📋 Step 2: Building and pushing Dashboard image..."
if [ -f "build_push_dashboard_image.sh" ]; then
    chmod +x build_push_dashboard_image.sh
    ./build_push_dashboard_image.sh
else
    echo "❌ build_push_dashboard_image.sh not found!"
    exit 1
fi
echo "✅ Dashboard image built and pushed successfully!"
echo ""

# Step 3: Build and Push Pipeline Image
echo "📋 Step 3: Building and pushing Pipeline image..."
if [ -f "build_push_pipeline_image.sh" ]; then
    chmod +x build_push_pipeline_image.sh
    ./build_push_pipeline_image.sh
else
    echo "❌ build_push_pipeline_image.sh not found!"
    exit 1
fi
echo "✅ Pipeline image built and pushed successfully!"
echo ""

# Step 4: Deploy Pipeline (terraform-02)
echo "📋 Step 4: Deploying Pipeline infrastructure..."
cd terraform/02-pipeline
terraform init
terraform apply -auto-approve
cd ../..
echo "✅ Pipeline infrastructure deployed successfully!"
echo ""

# Step 5: Deploy Dashboard (terraform-03)
echo "📋 Step 5: Deploying Dashboard infrastructure..."
cd terraform/03-dashboard
terraform init
terraform apply -auto-approve
cd ../..
echo "✅ Dashboard infrastructure deployed successfully!"
echo ""

echo "🎉 Complete deployment finished successfully!"
echo ""
echo "📦 Deployment Summary:"
echo "   ✅ Infrastructure (terraform-01)"
echo "   ✅ Dashboard image build & push"
echo "   ✅ Pipeline image build & push"
echo "   ✅ Pipeline infrastructure (terraform-02)"
echo "   ✅ Dashboard infrastructure (terraform-03)"
echo ""
echo "🚀 Your application is now deployed!"