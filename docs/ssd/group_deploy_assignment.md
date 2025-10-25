# SSD Group Deployment Report

## Purpose
Document the deployment of Dizzy's Disease to a shared staging environment and provide access details for Secure Software Development testers.

## Deployment Overview
- **Staging URL:** https://thankful-wave-09a5b000f.3.azurestaticapps.net/
- **Hosting:** Azure Static Web Apps (East US 2)
- **Backend:** Azure App Service (`https://dizzy-api-app.azurewebsites.net/`) + Azure PostgreSQL Flexible Server (`dizzy-db-57a0`)
- **Build Source:** Godot 4.4 HTML export (`capstone/build/web/`)
- **CI/CD:** `.github/workflows/deploy-static-web-app.yml` using `action: upload`

## Source Code Access
| Repo | URL | Notes |
|------|-----|-------|
| Classroom | https://github.com/Steve-at-Mohawk-College/capstone-project-Jinphinity | Full Godot project and backend; workflow secret `AZURE_STATIC_WEB_APPS_API_TOKEN`. |
| Personal Mirror | https://github.com/Jinphinity/capstone | Same project for individual development. |

## Tester Instructions
1. Launch https://thankful-wave-09a5b000f.3.azurestaticapps.net/
2. Register or login; passwords hashed (bcrypt) on the backend.
3. Exercise Continue/New Game flows, inventory, market; inspect calls to `https://dizzy-api-app.azurewebsites.net/...`
4. Verify API health at `https://dizzy-api-app.azurewebsites.net/health`
5. Offline mode available via `Skip Login`.

## Operational Notes
- Successful GitHub Actions runs push new builds automatically.
- Manual deploy command:
  ```bash
  swa deploy ./capstone/build/web \
    --app-name dizzy-disease-swa \
    --resource-group DizzySWA-RG \
    --subscription-id eedd13b0-fd70-45bc-99a0-7d1be4d779ec \
    --env production
  ```
- Backend container image: `dizzyacr57a0.azurecr.io/dizzy-api:latest`

## Evidence Checklist
- [x] Staging site reachable and interactive
- [x] API health endpoint returns `healthy`
- [x] GitHub repos expose buildable source
- [x] Automated workflow logs available in Actions tab
- [x] Manual `curl` registration test succeeds

## Deliverables Folder
Store supplemental screenshots, test logs, or sign-off forms in `docs/ssd/deliverables/`.
