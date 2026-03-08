---
page_type: sample
languages:
- javascript
- nodejs
products:
- app-service
description: "App Service Tutorial to be used with http://docs.microsoft.com/azure/app-service/containers/tutorial-troubleshoot-monitor"
urlFragment: "appsvc-troubleshoot-azure-monitor"
---

# Official Microsoft Sample

<!-- 
Guidelines on README format: https://review.docs.microsoft.com/help/onboard/admin/samples/concepts/readme-template?branch=master

Guidance on onboarding samples to docs.microsoft.com/samples: https://review.docs.microsoft.com/help/onboard/admin/samples/process/onboarding?branch=master

Taxonomies for products and languages: https://review.docs.microsoft.com/new-hope/information-architecture/metadata/taxonomies?branch=master
-->

This is a sample image converter app for Azure App Service. It converts JPG images to PNG using [Sharp](https://sharp.pixelplumbing.com/) and includes full Azure Developer CLI (azd) deployment with Application Insights monitoring.

Originally built as a companion to the [App Service troubleshooting tutorial](https://docs.microsoft.com/azure/app-service/containers/tutorial-troubleshoot-monitor).

> **Intentional errors for the tutorial:** Converting 1–3 images works normally. Selecting 4 or more images returns an HTTP 403 error, which generates failures visible in Azure Monitor / Application Insights.

## Architecture

- **Frontend**: Bootstrap 5.3 + vanilla JavaScript (no jQuery)
- **Backend**: Node.js 20 LTS / Express on Azure App Service (Linux)
- **Image processing**: Sharp (JPG → PNG conversion)
- **Monitoring**: Application Insights + Log Analytics workspace
- **Deployment**: Azure Developer CLI (azd) with Bicep infrastructure

## Contents

| File/folder       | Description                                |
|-------------------|--------------------------------------------|
| `server.js`       | Express server — API routes, CSRF middleware, static file serving |
| `package.json`    | Node.js project manifest (express, sharp, cookie-parser) |
| `public/index.html` | Main page (Bootstrap 5, `{{CSRF_TOKEN}}` placeholder injected at runtime) |
| `public/app.js`   | Client-side JavaScript (vanilla JS, fetch API, `/api/*` endpoints) |
| `public/starter-template.css` | Custom CSS for image selection and modals |
| `/images`         | Source JPG images and converted PNGs |
| `/thumbs`         | Thumbnail images for the convert modal |
| `/infra`          | Bicep infrastructure-as-code (App Service, App Insights, Log Analytics) |
| `azure.yaml`      | azd project manifest |
| `azd-deploy.ps1`  | Interactive deployment script with tenant/subscription/RG prompts |
| `deploy.ps1`      | Legacy Azure CLI deployment script |

### API Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| `GET`  | `/` | Serves `index.html` with CSRF token injected |
| `GET`  | `/api/thumbs` | Returns JSON array of thumbnail filenames |
| `GET`  | `/api/images?ext=` | Returns HTML list of images filtered by extension |
| `POST` | `/api/process` | Converts selected JPGs to PNG (403 if 4+ images) |
| `POST` | `/api/delete` | Deletes all `converted_*.png` files |

## Prerequisites

- [Node.js 20+](https://nodejs.org/)
- [Azure Developer CLI (azd)](https://aka.ms/azd-install)
- [Azure CLI (az)](https://aka.ms/install-azure-cli)
- An Azure subscription

## Local Development

```bash
npm install
npm start          # Starts on http://localhost:8080
```

## Deployment

### Option 1: Interactive Script (recommended)

The interactive script prompts for tenant, subscription, resource group, and location:

```powershell
.\azd-deploy.ps1
```

### Option 2: Manual azd commands

```powershell
# Initialize and configure
azd init --no-prompt
azd env new <env-name>
azd env set AZURE_ENV_NAME <env-name>
azd env set AZURE_LOCATION <location>            # e.g. westus2
azd env set AZURE_SUBSCRIPTION_ID <sub-id>
azd env set AZURE_RESOURCE_GROUP <rg-name>
azd env set APP_SERVICE_SKU B1

# Authenticate
azd auth login --tenant-id <tenant-id>

# Provision infrastructure + deploy app
azd up --no-prompt
```

### What gets deployed

| Resource | Description |
|----------|-------------|
| **App Service Plan** (B1 Linux) | Hosts the Node.js web app |
| **App Service** | Node.js 20 LTS web app with HTTPS-only, TLS 1.2 |
| **Log Analytics Workspace** | Centralized log storage (30-day retention) |
| **Application Insights** | APM: request tracking, failures, performance, live metrics |

## Monitoring

Application Insights auto-instrumentation is enabled via app settings:

- `APPLICATIONINSIGHTS_CONNECTION_STRING` — connects telemetry to the App Insights instance
- `ApplicationInsightsAgent_EXTENSION_VERSION = ~3` — enables server-side auto-instrumentation

### Query 403 errors in App Insights

```kql
requests
| where resultCode == "403"
| project timestamp, name, url, resultCode, duration, client_IP
| order by timestamp desc
```

### View logs

```powershell
# Stream live logs
az webapp log tail --name <app-name> --resource-group <rg-name>

# Open App Insights in Azure Portal
az monitor app-insights component show --app <appi-name> -g <rg-name> --query "portalUrl" -o tsv
```

### Tear down

```powershell
azd down --force --purge
```

## Intentional Error Behavior

This app is designed for the Azure Monitor troubleshooting tutorial:

| Images selected | Result |
| --- | --- |
| 1–3 | Converts successfully (HTTP 200) |
| 4+ | Returns **HTTP 403** — generates errors for App Insights |

Use Tools → Convert to PNG, select 4+ thumbnails, and click Convert to generate 403 errors. Then inspect the failures in Application Insights → Failures blade.

## Security Features

- **CSRF protection**: Double Submit Cookie pattern (cookie + POST parameter comparison)
- **Input validation**: Image filenames validated against strict regex, extensions whitelisted
- **Restricted deletion**: Only `converted_*.png` files can be deleted
- **HTTPS-only**: Enforced at the App Service level
- **TLS 1.2 minimum**: Configured in Bicep
- **FTPS disabled**: No FTP access to the app

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
