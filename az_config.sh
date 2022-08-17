#!/bin/bash
# This file configures deloyment of Azure cli to manage secrets from Vault.

sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo

sudo dnf install azure-cli -y
# Azure Vault
az login --identity -u /subscriptions/8cbd35f6-390d-420b-8799-db326c08ee80/resourcegroups/UAENorthTestServer/providers/Microsoft.ManagedIdentity/userAssignedIdentities/vm-identity

az keyvault secret download --vault-name ethiopia-vault --name vpnserver-pub --file test.pub
