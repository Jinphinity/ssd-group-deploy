# SSD Group Deployment Report

## Purpose
Demonstrate and document deployment of the Dizzy's Disease application to a shared staging environment, and publish buildable source code for peer testing in the Secure Software Development course.

## Deployment Overview
- **Staging URL:** https://thankful-wave-09a5b000f.3.azurestaticapps.net/
- **Hosting Platform:** Azure Static Web Apps (Free tier, East US 2)
- **Backend:** Azure App Service (`https://dizzy-api-app.azurewebsites.net/`) connecting to Azure PostgreSQL Flexible Server (`dizzy-db-57a0`)
- **Web Build Source:** Godot 4.4 HTML5 export located at `capstone/build/web/`
- **Deploy Automation:** GitHub Actions workflow `.github/workflows/deploy-static-web-app.yml` (action `upload`)

## Source Code Repositories
| Repository | Access | Notes |
|------------|--------|-------|
| Classroom repo | https://github.com/Steve-at-Mohawk-College/capstone-project-Jinphinity | Contains full Godot project, FastAPI backend, and SSD docs. Workflow uses secret `AZURE_STATIC_WEB_APPS_API_TOKEN`. |
| Personal repo | https://github.com/Jinphinity/capstone | Mirrors the same project for individual development. |

Both repositories expose the entire Godot project (`capstone/`), backend (`capstone/api/`), and the deployment workflow.

## Access Instructions for Testers
1. **Web Application**
   - Visit https://thankful-wave-09a5b000f.3.azurestaticapps.net/
   - Create a test account via the login screen (no email verification required).
   - Post-registration, exercise Continue/New Game flows.
2. **API Health Check**
   - Call `https://dizzy-api-app.azurewebsites.net/health` for a JSON status report.
3. **Credentials / Test Accounts**
   - Create ad-hoc accounts; passwords hashed with bcrypt on the backend.
4. **Backend evidence**
   - Login, registration, and inventory requests hit the Azure App Service; use browser dev tools to inspect `https://dizzy-api-app.azurewebsites.net/...` calls.
5. **Offline fallback**
   - `Skip Login` runs in offline mode for scenarios without backend access.

## Operational Notes
- Deployments are triggered automatically on pushes to `main` via the GitHub Actions workflow.
- Manual deploy: `swa deploy ./capstone/build/web --app-name dizzy-disease-swa --resource-group DizzySWA-RG --subscription-id eedd13b0-fd70-45bc-99a0-7d1be4d779ec --env production`
- API container image: `dizzyacr57a0.azurecr.io/dizzy-api:latest`
- Database: `dizzy-db-57a0.postgres.database.azure.com`, database `dizzy`

## Evidence Checklist
- [x] Staging URL reachable and interactive
- [x] API `/health` returning healthy status
- [x] Source repos contain full buildable project
- [x] Automated workflow logs attached in Actions history
- [x] Direct curl registration test succeeds (`apitest@example.com`)

## Next Steps
- Add screenshots or test logs to `docs/ssd/deliverables/`
- Document any penetration test findings or remediation plans alongside future SSD assignments.
