# Dizzy's Disease - Complete Game Application

**Last Updated**: October 31, 2025 | **Status**: ✅ Production Ready

## Deployment Status

### Azure Static Web Apps
- **WebGL Game**: Deployed and live
- **Status**: ✅ Active
- **CI/CD**: GitHub Actions automatic deployment on push to main
- **Endpoint**: See Azure dashboard

### Local Development

#### Prerequisites
- Docker & Docker Compose
- Python 3.11+ (for local backend)
- Godot 4.4 (for game development)

#### Quick Start with Docker
```bash
docker-compose up --build
```

Services will be available at:
- Game Server: http://localhost:8090 (WebGL local)
- API Backend: http://localhost:8000 (FastAPI)
- Database: PostgreSQL on port 5432

#### Local Game Testing
```bash
python3 serve_local.py --port 8090
```

Then open http://localhost:8090 in browser

#### Local Backend Testing
```bash
cd api
pip install -r requirements.txt
python main.py
```

## Authentication

### Password Requirements
- Minimum 8 characters
- Uppercase letter required
- Lowercase letter required
- Digit required
- Symbol required (@, #, $, etc.)

### Test Credentials
Register with a strong password like:
- Email: test@example.com
- Password: Password123@

## Project Structure

```
capstone/               # Game source code
├── autoload/          # Global singletons (Api, Auth, Save, etc.)
├── common/            # Shared systems and UI
├── entities/          # NPC and character definitions
├── stages/            # Game levels/stages
└── tools/             # Development and testing utilities

api/                   # Backend API
├── main.py            # FastAPI application
├── auth.py            # Authentication and JWT
├── db.py              # Database models
├── migrations/        # Database migrations
└── sql/               # SQL schemas

docker-compose.yml     # Docker deployment configuration
export_presets.cfg     # Godot WebGL export settings
```

## Troubleshooting

### Port Already in Use
If port 8000 or 8090 are in use:
```bash
lsof -i :8000  # Check port 8000
python3 serve_local.py --port 8091  # Use different port
```

### Authentication Failures
Ensure password meets all requirements:
- At least 8 characters
- Contains: uppercase, lowercase, digit, symbol

### Game Won't Load
- Check browser console (F12)
- Verify API is running: `curl http://localhost:8000/health`
- Check CORS headers in nginx/proxy

## Documentation

See CLAUDE.md for complete project documentation and deployment guides.
For archived/outdated documentation, see docs-archive/