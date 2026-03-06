
# =============================================================================
# Deploy Azure App Service with PHP sample application
# Deploys the "App-Service-Troubleshoot-Azure-Monitor" sample to an Azure
# Web App using local Git deployment.
# =============================================================================

# --------------- Configuration ---------------
$resourceGroup = "rg-pierrer-ToolsDemo"
$location = "Westus2"
$appServicePlan = "ToolsDemoPlan"
$appName = "ToolsDemo"
$sku = "B1"
$runtime = 'PHP:8.4'

# --------------- Provision Azure Resources ---------------

# Create the resource group
az group create --name $resourceGroup --location $location

# Create the App Service plan (B1 = Basic tier, Linux — required for PHP)
az appservice plan create --name $appServicePlan --resource-group $resourceGroup --sku $sku --is-linux

# Create the web app with local Git deployment enabled
az webapp create --resource-group $resourceGroup --plan $appServicePlan --name $appName --runtime $runtime --deployment-local-git

# Set the deployment branch to 'main'
az webapp config appsettings set --name $appName --resource-group $resourceGroup --settings DEPLOYMENT_BRANCH='main'

# Enable basic auth on the SCM site (required for local git deployment)
az resource update --resource-group $resourceGroup --name scm --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent "sites/$appName" --set properties.allow=true
az resource update --resource-group $resourceGroup --name ftp --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent "sites/$appName" --set properties.allow=true

# --------------- Retrieve Publishing Credentials ---------------

# Fetch the app-level publishing credentials (auto-generated, no hardcoded passwords)
$credsJson = az webapp deployment list-publishing-credentials --resource-group $resourceGroup --name $appName --query '{user:publishingUserName, pass:publishingPassword}' -o json
$creds = $credsJson | ConvertFrom-Json
$gitUrl = "https://$($creds.user):$($creds.pass)@$appName.scm.azurewebsites.net/$appName.git"

# --------------- Clone and Deploy Sample App ---------------

# Clone the sample PHP application (skip if already cloned)
if (-not (Test-Path "App-Service-Troubleshoot-Azure-Monitor")) {
    git clone https://github.com/Azure-Samples/App-Service-Troubleshoot-Azure-Monitor
}
cd App-Service-Troubleshoot-Azure-Monitor
git branch -m main

# Push the sample app to Azure via local Git deployment
git remote remove azure 2>$null
git remote add azure $gitUrl
git push azure main