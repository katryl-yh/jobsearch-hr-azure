#!/bin/bash
set -e

export MSYS_NO_PATHCONV=1

# Load environment variables
export $(cat .env.azure | xargs)

# Login to ACR
echo "🔐 Logging into ACR..."
az acr login --name $ACR_NAME

# Get the full registry URL
REGISTRY="${ACR_NAME}.azurecr.io"

# Set image tags
DAGSTER_IMAGE="${REGISTRY}/${CONTAINER_NAME}:${TAG:-latest}"

echo "🏗️  Building Dagster image for AMD64..."
docker buildx build \
  --platform linux/amd64 \
  --file Dockerfile.elt \
  --tag $DAGSTER_IMAGE \
  --push \
  .

echo "✅ Dagster image pushed: $DAGSTER_IMAGE"

echo ""
echo "📦 Images built and pushed:"
echo "   - $DAGSTER_IMAGE"
echo ""
echo "✅ Build complete!"