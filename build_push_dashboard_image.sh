#!/bin/bash
set -e

export MSYS_NO_PATHCONV=1

# Load environment variables
export $(cat .env.dashboard | xargs)

# Login to ACR
echo "🔐 Logging into ACR..."
az acr login --name $ACR_NAME

# Get the full registry URL
REGISTRY="${ACR_NAME}.azurecr.io"

# Set image tags
DASHBOARD_IMAGE="${REGISTRY}/${CONTAINER_NAME}:${TAG:-latest}"

echo "🏗️  Building Dashboard image for AMD64..."
docker buildx build \
  --platform linux/amd64 \
  --file Dockerfile.serve \
  --tag $DASHBOARD_IMAGE \
  --push \
  .

echo "✅ Dashboard image pushed: $DASHBOARD_IMAGE"

echo ""
echo "📦 Images built and pushed:"
echo "   - $DASHBOARD_IMAGE"
echo ""
echo "✅ Build complete!"