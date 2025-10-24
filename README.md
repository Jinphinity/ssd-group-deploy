# SSD Group Deploy - Academic Assessment

Minimal deployment repository for academic assessment containing a Godot 4.4 game with mock API backend.

## Prerequisites

- Godot 4.4 or later
- Python 3.8+

## Quick Start

1. **Start API Server:**
   ```bash
   chmod +x start_test_environment.sh
   ./start_test_environment.sh
   ```

2. **Open in Godot:**
   - Launch Godot 4.4
   - Import project using `project.godot`
   - Press F5 to run

## Test Credentials

**Login Screen:**
- Username: `test_user`
- Password: `test_password`

**Character Creation:**
- Create any character with default stats
- All systems are functional in test mode

## Build Instructions

**Desktop Export:**
1. Open project in Godot
2. Go to Project → Export
3. Select platform and export

**Web Export:**
1. Install web export templates in Godot
2. Use export presets configuration
3. Export for web deployment

## API Endpoints

Mock API server runs on `http://localhost:8000` with endpoints for:
- User authentication
- Character management
- Game state persistence

## Project Structure

- `autoload/` - Global systems and services
- `common/` - Shared game components
- `stages/` - Game levels and scenes
- `assets/` - Sprites and resources
- `mock_api_server.py` - Backend API simulation
- `serve_local.py` - Local development server

For academic assessment purposes only.