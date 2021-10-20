#Variables
environment="test"
prefix="Babosbird"
location="westeurope"
containerName="scripts"
scriptPath="terraform/scripts"
scriptName="configure-jumpbox-vm.sh"
postfix="1992"
storageAccountResourceGroupName="rg$postfix"
storageAccountName="scriptstorage$postfix"
sku="Standard_LRS"
subscriptionName=$(az account show --query name --output tsv)

# Create resource group
echo "Checking if [$storageAccountResourceGroupName] resource group actually exists in the [$subscriptionName] subscription..."
az group show --name $storageAccountResourceGroupName &>/dev/null

if [[ $? != 0 ]]; then
    echo "No [$storageAccountResourceGroupName] resource group actually exists in the [$subscriptionName] subscription"
    echo "Creating [$storageAccountResourceGroupName] resource group in the [$subscriptionName] subscription..."

    # Create the resource group
    az group create \
        --name $storageAccountResourceGroupName \
        --location $location 1>/dev/null

    if [[ $? == 0 ]]; then
        echo "[$storageAccountResourceGroupName] resource group successfully created in the [$subscriptionName] subscription"
    else
        echo "Failed to create [$storageAccountResourceGroupName] resource group in the [$subscriptionName] subscription"
        exit -1
    fi
else
    echo "[$storageAccountResourceGroupName] resource group already exists in the [$subscriptionName] subscription"
fi

# Create storage account
echo "Checking if [$storageAccountName] storage account actually exists in the [$subscriptionName] subscription..."
az storage account --name $storageAccountName &>/dev/null

if [[ $? != 0 ]]; then
    echo "No [$storageAccountName] storage account actually exists in the [$subscriptionName] subscription"
    echo "Creating [$storageAccountName] storage account in the [$subscriptionName] subscription..."

    az storage account create \
        --resource-group $storageAccountResourceGroupName \
        --name $storageAccountName \
        --sku $sku \
        --encryption-services blob 1>/dev/null

    # Create the storage account
    if  [[ $? == 0 ]]; then
        echo "[$storageAccountName] storage account successfully created in the [$subscriptionName] subscription"
    else
        echo "Failed to create [$storageAccountName] storage account in the [$subscriptionName] subscription"
        exit -1
    fi
else
    echo "[$storageAccountName] storage account already exists in the [$subscriptionName] subscription"
fi

# Get storage account key
echo "Retrieving the primary key of the [$storageAccountName] storage account..."
storageAccountKey=$(az storage account keys list --resource-group $storageAccountResourceGroupName --account-name $storageAccountName --query [0].value -o tsv)

if [[ -n $storageAccountKey ]]; then
    echo "Primary key of the [$storageAccountName] storage account successfully retrieved"
else
    echo "Failed to retrieve the primary key of the [$storageAccountName] storage account"
    exit -1
fi

# Create blob container
echo "Checking if [$containerName] container actually exists in the [$storageAccountName] storage account..."
az storage container show \
    --name $containerName \
    --account-name $storageAccountName \
    --account-key $storageAccountKey &>/dev/null

if [[ $? != 0 ]]; then
    echo "No [$containerName] container actually exists in the [$storageAccountName] storage account"
    echo "Creating [$containerName] container in the [$storageAccountName] storage account..."

    # Create the container
    az storage container create \
        --name $containerName \
        --account-name $storageAccountName \
        --account-key $storageAccountKey 1>/dev/null

    if  [[ $? == 0 ]]; then
        echo "[$containerName] container successfully created in the [$storageAccountName] storage account"
    else
        echo "Failed to create [$containerName] container in the [$storageAccountName] storage account"
        exit -1
    fi
else
    echo "[$containerName] container already exists in the [$storageAccountName] storage account"
fi

# Copy script as blob to the storage account container
az storage blob upload \
    --container-name $containerName \
    --name $scriptName \
    --account-name $storageAccountName \
    --account-key $storageAccountKey \
    --file "~/workspace/private-aks-cluster-terraform-devops/$scriptPath/$scriptName"

if  [[ $? == 0 ]]; then
    echo "[$scriptName] successfully copied to the [$containerName] container in the [$storageAccountName] storage account"
else
    echo "Failed to copy the [$scriptName] script to the [$containerName] container in the [$storageAccountName] storage account"
    exit -1
fi

# Print data
echo "----------------------------------------------------------------------------------------------"
echo "storageAccountName: $storageAccountName"
echo "containerName: $containerName"

echo "##vso[task.setvariable variable=storageAccountResourceGroupName;]$storageAccountResourceGroupName"
echo "##vso[task.setvariable variable=storageAccountName;]$storageAccountName"
echo "##vso[task.setvariable variable=storageAccountKey;]$storageAccountKey"
echo "##vso[task.setvariable variable=ok;]true"
