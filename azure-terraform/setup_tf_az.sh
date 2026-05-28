#!/bin/bash

C_WD=$(pwd)

# ===== Vérifier si az et terraform sont installés =====

echo "Vérification des dépendances..."

if ! command -v az &> /dev/null; then
  echo "missing azure cli; installing the dependencies ..."
  brew update && brew install azure-cli
fi
if ! command -v terraform &> /dev/null; then
  echo "missing terraform; installing the dependencies ..."
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform
fi

echo "... success verification"

if ! az account show &> /dev/null; then
  echo "you're not connected ..."
  az login
fi

AZ_SUB=$(az account show --query "name" -o tsv)
AZ_SUB_ID=$(az account show --query "id" -o tsv)
AZ_UNAME=$(az account show --query "user.name" -o tsv)
AZ_TNT_ID=$(az account show --query "tenantId" -o tsv)
AZ_TNT_DEF_DMN=$(az account show --query "tenantDefaultDomain" -o tsv)

if [ -z "$AZ_SUB" ] || [ -z "$AZ_SUB_ID" ] || [ -z "$AZ_UNAME" ] ||
[ -z "$AZ_TNT_ID" ] || [ -z "$AZ_TNT_DEF_DMN" ]; then
  echo "error, one variable is not set ..."
  exit 1
fi

echo "Authentificated ✅"
echo " - Compte: $AZ_UNAME"
echo " - Subscription: $AZ_SUB"
echo " - Subscription ID: $AZ_SUB_ID"
echo " - Tenant ID: $AZ_TNT_ID"
echo " - Default domain: $AZ_TNT_DEF_DMN"

if az account set --subscription "$AZ_SUB_ID"; then
  echo "subscription changed ✅"
else
  echo "subscription not changed, error"
fi

SRVC_NAME="terraform-spl"
TFVARS="$C_WD/terraform.tfvars"

echo "Creating Service: $SRVC_NAME"
SP_ID=$(az ad sp list --query "[?starts_with(displayName, '$SRVC_NAME')].appId" -o tsv)

if [ -n "$SP_ID" ]; then
  echo "service $SRVC_NAME already exist ✅: [ $SP_ID ]"
  if [ ! -f "$TFVARS" ]; then
    output=$(az ad sp show --id "$SP_ID")
    C_ID=$(echo "$output" | jq -r ".appId")
    NAME=$(echo "$output" | jq -r ".displayName")

    echo "$C_ID, $NAME, $PSWD, $TENANT"
    touch "$TFVARS"
    cat >  "$TFVARS" << EOF
client_id       = "$C_ID"
subscription_id = "$AZ_SUB_ID"
tenant_id       = "$AZ_TNT_ID"
EOF
  fi
else
  echo "service don't existe, begin creating ..."
  output=$(az ad sp create-for-rbac --name "$SRVC_NAME" --role="Contributor" --scopes="/subscriptions/$AZ_SUB_ID")

  C_ID=$(echo "$output" | jq -r ".appId")
  NAME=$(echo "$output" | jq -r ".displayName")
  PSWD=$(echo "$output" | jq -r ".password")
  TENANT=$(echo "$output" | jq -r ".tenant")

  touch "$TFVARS"
  cat >  "$TFVARS" << EOF
client_id       = "$C_ID"
client_secret   = "$PSWD"
subscription_id = "$AZ_SUB_ID"
tenant_id       = "$TENANT"
EOF

fi


chmod 600 "$TFVARS"

client_id=$(cat "$TFVARS" | grep "client_id")

echo "$TFVARS created (permissions: 600) ✅"

echo ""
echo "=== Complet Setup ==="
echo "Variables exported:"
echo " - $client_id "
echo " - subscription_id  = $AZ_SUB_ID"
echo " - tenant_id  = $AZ_TNT_ID"
echo ""
echo "File: $TFVARS"

TF_FLD="terraform-azure"

if [ ! -d "$TF_FLD" ]; then
  echo "creating terraform folder [$TF_FLD] ..."
  mkdir "$TF_FLD" || { echo "ERROR mkdir "; exit 1; }
fi

echo "Enter $TF_FLD ..."
cd "$TF_FLD" || { echo "ERROR cd"; exit 1; }
if [ ! -f "main.tf" ]; then
  echo "Creating main.tf ..."
  cat > "main.tf" << EOF
# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "myTFResourceGroup"
  location = "westus2"
}
EOF
fi

echo "terraform init"
# Terraform init
terraform init || { echo "ERROR init "; exit 1; }

echo "terraform fmt"
# Terraform fmt
terraform fmt || { echo "ERROR  fmt "; exit 1; }

echo "terraform validate"
# Terraform validate
terraform validate || { echo "ERROR  validate "; exit 1; }

echo "terraform plan"
# Terraform plan
terraform plan || { echo "ERROR  plan "; exit 1; }

echo "-----------------------------"
echo "ALL step has been succeed ✅"

pip3 install InquirerPy

python3 validate.py

if [ $? -eq 0 ]; then
  terraform apply
fi

