<#
.SYNOPSIS
    Deploy the Image Converter app to Azure using azd (Azure Developer CLI).

.DESCRIPTION
    Interactively prompts for Azure tenant, subscription, resource group, and
    location, then provisions infrastructure and deploys the application.

.NOTES
    Prerequisites:
      - Azure Developer CLI (azd): https://aka.ms/azd-install
      - Azure CLI (az): https://aka.ms/install-azure-cli
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Helpers ────────────────────────────────────────────────────────────────

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error "'$Name' is not installed. See https://aka.ms/azd-install"
    }
}

function Select-FromList {
    param(
        [Parameter(Mandatory)][array]$Items,
        [Parameter(Mandatory)][string]$Label,
        [string]$DisplayProperty,
        [string]$ValueProperty
    )
    Write-Host ""
    Write-Host "── $Label ──" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $display = if ($DisplayProperty) { $Items[$i].$DisplayProperty } else { $Items[$i] }
        Write-Host "  [$($i + 1)] $display"
    }
    do {
        $choice = Read-Host "Select (1-$($Items.Count))"
    } while (-not ($choice -match '^\d+$') -or [int]$choice -lt 1 -or [int]$choice -gt $Items.Count)

    $selected = $Items[[int]$choice - 1]
    if ($ValueProperty) { return $selected.$ValueProperty } else { return $selected }
}

# ─── Pre-flight ─────────────────────────────────────────────────────────────

Assert-Command 'az'
Assert-Command 'azd'

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   Image Converter – Azure Deployment (azd)   ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Green

# ─── 1. Tenant Selection ────────────────────────────────────────────────────

Write-Host ""
Write-Host "Fetching Azure tenants…" -ForegroundColor Yellow
$tenants = az account tenant list --query "[].{name:displayName, id:tenantId}" -o json | ConvertFrom-Json

if ($tenants.Count -eq 0) {
    Write-Error "No Azure tenants found. Run 'az login' first."
}
elseif ($tenants.Count -eq 1) {
    $tenantId = $tenants[0].id
    Write-Host "Using tenant: $($tenants[0].name) ($tenantId)" -ForegroundColor Green
}
else {
    $tenantId = Select-FromList -Items $tenants -Label "Select Azure Tenant" `
        -DisplayProperty 'name' -ValueProperty 'id'
}

# Log in to the selected tenant (ensures token scope is correct)
Write-Host ""
Write-Host "Logging into tenant $tenantId…" -ForegroundColor Yellow
az login --tenant $tenantId --only-show-errors | Out-Null

# ─── 2. Subscription Selection ──────────────────────────────────────────────

Write-Host ""
Write-Host "Fetching subscriptions…" -ForegroundColor Yellow
$subs = az account list --tenant $tenantId --query "[?state=='Enabled'].{name:name, id:id}" -o json | ConvertFrom-Json

if ($subs.Count -eq 0) {
    Write-Error "No enabled subscriptions found in tenant $tenantId."
}
elseif ($subs.Count -eq 1) {
    $subscriptionId = $subs[0].id
    Write-Host "Using subscription: $($subs[0].name) ($subscriptionId)" -ForegroundColor Green
}
else {
    $subscriptionId = Select-FromList -Items $subs -Label "Select Azure Subscription" `
        -DisplayProperty 'name' -ValueProperty 'id'
}

az account set --subscription $subscriptionId

# ─── 3. Resource Group ──────────────────────────────────────────────────────

Write-Host ""
Write-Host "Fetching resource groups…" -ForegroundColor Yellow
$rgs = az group list --subscription $subscriptionId --query "[].{name:name, location:location}" -o json | ConvertFrom-Json

$rgOptions = @($rgs | ForEach-Object { "$($_.name)  ($($_.location))" })
$rgOptions += "[Create new resource group]"

$rgChoice = Select-FromList -Items $rgOptions -Label "Select Resource Group"

if ($rgChoice -eq "[Create new resource group]") {
    $rgName = Read-Host "Enter new resource group name"
    $location = Read-Host "Enter Azure location (e.g. eastus2, westus2, westeurope)"
    Write-Host "Creating resource group '$rgName' in '$location'…" -ForegroundColor Yellow
    az group create --name $rgName --location $location --subscription $subscriptionId | Out-Null
}
else {
    # Parse the name from "rgname  (location)"
    $rgName = ($rgChoice -split '\s{2}\(')[0]
    $location = ($rgs | Where-Object { $_.name -eq $rgName }).location
}

Write-Host ""
Write-Host "Selected: RG=$rgName  Location=$location" -ForegroundColor Green

# ─── 4. Environment Name ────────────────────────────────────────────────────

$defaultEnv = $rgName -replace '[^a-zA-Z0-9-]', ''
$envName = Read-Host "Enter azd environment name (default: $defaultEnv)"
if ([string]::IsNullOrWhiteSpace($envName)) { $envName = $defaultEnv }

# ─── 5. Optional Overrides ──────────────────────────────────────────────────

$skuInput = Read-Host "App Service SKU [B1]"
$sku = if ([string]::IsNullOrWhiteSpace($skuInput)) { 'B1' } else { $skuInput }

# ─── 6. Initialise azd environment ──────────────────────────────────────────

Write-Host ""
Write-Host "Configuring azd environment '$envName'…" -ForegroundColor Yellow

azd init --no-prompt 2>$null  # idempotent – safe if already initialised
azd env new $envName 2>$null

azd env set AZURE_ENV_NAME        $envName
azd env set AZURE_LOCATION        $location
azd env set AZURE_SUBSCRIPTION_ID $subscriptionId
azd env set AZURE_RESOURCE_GROUP  $rgName
azd env set APP_SERVICE_SKU       $sku

# Also log azd into the same tenant
azd auth login --tenant-id $tenantId

# ─── 7. Provision & Deploy ──────────────────────────────────────────────────

Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Ready to provision infrastructure and deploy"   -ForegroundColor Cyan
Write-Host " Tenant:        $tenantId"
Write-Host " Subscription:  $subscriptionId"
Write-Host " Resource Group: $rgName"
Write-Host " Location:       $location"
Write-Host " Environment:    $envName"
Write-Host " SKU:            $sku"
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "Proceed? (Y/n)"
if ($confirm -match '^[Nn]') {
    Write-Host "Aborted." -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "Running azd up (provision + deploy)…" -ForegroundColor Yellow
azd up --no-prompt

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "Run 'azd monitor' to view logs, or 'azd down' to tear down resources." -ForegroundColor Yellow
