#!/bin/bash
set -e

export MSYS_NO_PATHCONV=1

# Load environment variables
export $(cat .env.azure | xargs)

echo "🔐 Getting ACR credentials..."
export ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)
export ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)

echo "🔐 Getting Storage Account key..."
export STORAGE_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP \
  --account-name $STORAGE_ACCOUNT_NAME \
  --query "[0].value" -o tsv)

# Debug: Show what was loaded
echo "🔍 Debug - Environment variables:"
echo "DUCKDB_PATH: $DUCKDB_PATH"
echo "FILE_SHARE_NAME: $FILE_SHARE_NAME"
echo "STORAGE_ACCOUNT_NAME: $STORAGE_ACCOUNT_NAME"
echo "ACR_NAME: $ACR_NAME"
echo "RESOURCE_GROUP: $RESOURCE_GROUP"
echo "CONTAINER_NAME: $CONTAINER_NAME"
echo "IMAGE_NAME: $IMAGE_NAME"

echo "🚀 Deploying container..."
az container create \
  --verbose \
  --debug \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --image ${ACR_NAME}.azurecr.io/${IMAGE_NAME} \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --azure-file-volume-account-name $STORAGE_ACCOUNT_NAME \
  --azure-file-volume-account-key $STORAGE_KEY \
  --azure-file-volume-share-name $FILE_SHARE_NAME \
  --azure-file-volume-mount-path /mnt \
  --os-type Linux \
  --cpu 1 \
  --memory 2 \
  --ports 3000 \
  --ip-address Public \
  --environment-variables \
      DUCKDB_PATH=$DUCKDB_PATH

echo "✅ Deployment complete!"