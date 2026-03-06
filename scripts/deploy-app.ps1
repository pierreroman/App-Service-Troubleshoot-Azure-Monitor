<#
.SYNOPSIS
    Post-provision hook: zip-deploys the PHP app to the Azure Web App
    provisioned by azd.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Read outputs from the azd environment (set by Bicep outputs)
$appName = azd env get-value WEB_APP_NAME
$rg      = azd env get-value AZURE_RESOURCE_GROUP

if (-not $appName -or -not $rg) {
    Write-Error "WEB_APP_NAME or AZURE_RESOURCE_GROUP not set. Run 'azd provision' first."
}

Write-Host "Deploying to App Service '$appName' in RG '$rg'..." -ForegroundColor Cyan

# Build a zip of only the app files (exclude deployment artifacts)
$zipPath = Join-Path $env:TEMP "imageconverter-deploy.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$appRoot = Split-Path $PSScriptRoot -Parent
$include = @(
    "$appRoot\*.php",
    "$appRoot\*.js",
    "$appRoot\*.css",
    "$appRoot\images",
    "$appRoot\thumbs"
)

# Use Compress-Archive with explicit file list
$filesToZip = @()
$filesToZip += Get-ChildItem -Path $appRoot -Include '*.php','*.js','*.css' -File
$filesToZip += Get-ChildItem -Path "$appRoot\images" -File | ForEach-Object { $_ }
$filesToZip += Get-ChildItem -Path "$appRoot\thumbs" -File | ForEach-Object { $_ }

# Create a temp staging folder to preserve directory structure
$staging = Join-Path $env:TEMP "imageconverter-staging"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging | Out-Null
New-Item -ItemType Directory -Path "$staging\images" | Out-Null
New-Item -ItemType Directory -Path "$staging\thumbs" | Out-Null

# Copy app files (use wildcard path so -Include works without -Recurse)
Get-ChildItem -Path "$appRoot\*" -Include '*.php','*.js','*.css' -File | Copy-Item -Destination $staging
Copy-Item -Path "$appRoot\images\*" -Destination "$staging\images" -Recurse
Copy-Item -Path "$appRoot\thumbs\*" -Destination "$staging\thumbs" -Recurse

# Zip the staging folder
Compress-Archive -Path "$staging\*" -DestinationPath $zipPath -Force

Write-Host "Package created: $zipPath ($('{0:N0}' -f ((Get-Item $zipPath).Length / 1KB)) KB)" -ForegroundColor Green

# Deploy via az webapp deploy (zip deploy, no build)
Write-Host "Uploading to Azure..." -ForegroundColor Yellow
az webapp deploy `
    --resource-group $rg `
    --name $appName `
    --src-path $zipPath `
    --type zip `
    --async false

# Cleanup
Remove-Item $staging -Recurse -Force
Remove-Item $zipPath -Force

$uri = azd env get-value WEB_URI
Write-Host ""
Write-Host "Deployment complete!  $uri" -ForegroundColor Green
