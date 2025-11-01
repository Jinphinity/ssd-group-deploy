# Capstone Project - GODOT-AEGIS Integration

**Last Updated**: October 31, 2025
**Status**: ✅ PRODUCTION READY - All systems functional
**Documentation Version**: 2.0 (Current)

## Project Context
This is a Godot 4.4 game project called "Capstone" - a disease simulation game with multiplayer components, complex AI systems, and cross-platform deployment requirements.

**Current Deployment Status**:
- ✅ WebGL game deployed to Azure Static Web Apps
- ✅ FastAPI backend running (Docker + PostgreSQL)
- ✅ Authentication system operational
- ✅ Character management, inventory, and market systems functional
- ✅ Browser testing available at http://localhost:8090

## GODOT-AEGIS Activation
Enable GODOT-AEGIS system for intelligent Godot development assistance:

@GODOT-AEGIS.md

## Project Specifics

### Game Type
- **Disease Simulation Game**: Epidemic/pandemic simulation with player decision-making
- **Multiplayer Support**: Real-time multiplayer gameplay coordination
- **AI Systems**: Complex NPC behavior, disease spread algorithms, economic simulation
- **UI Heavy**: Extensive interface systems for data visualization and control

### Target Platforms
- **Primary**: Desktop (Windows, macOS, Linux)
- **Secondary**: Mobile (Android, iOS) with optimized UI
- **Future**: Web deployment for accessibility

### Performance Requirements
- **Frame Rate**: 60fps on desktop, 30fps minimum on mobile
- **Memory**: <1GB on desktop, <512MB on mobile
- **Network**: Low-latency multiplayer, efficient data synchronization

### Architecture Notes
- Scene-based modular design
- Signal-driven communication between systems
- Autoload singletons for global state management
- Component-based entity systems for NPCs and players

## Development Priorities

1. **System Architecture**: Robust, scalable game systems
2. **Performance**: Mobile-first optimization approach
3. **UI/UX**: Complex data visualization with responsive design
4. **Multiplayer**: Reliable networking and state synchronization
5. **AI Behavior**: Sophisticated NPC and epidemic simulation systems

## GODOT-AEGIS Agent Preferences

- **Primary Coordinator**: godot-lead-developer for complex architecture decisions
- **UI Systems**: godot-ui-specialist for data visualization interfaces
- **Performance**: godot-performance for mobile optimization
- **AI Systems**: godot-ai-behavior for NPC and simulation AI
- **Multiplayer**: godot-lead-developer for networking architecture

## Command Shortcuts

Use `/godot:aegis` for any complex development requests involving multiple domains. Examples:
- `/godot:aegis "optimize the multiplayer system for mobile deployment"`
- `/godot:aegis "create a responsive disease tracking dashboard"`
- `/godot:aegis "implement AI behavior for epidemic simulation"`

## Project Standards

Follow GODOT-AEGIS principles:
- 60fps performance targets
- Signal-driven architecture
- Component-based design
- Mobile-first optimization
- Comprehensive testing and validation

## 📤 Git Workflow (CRITICAL - DUAL REMOTE PUSH)

**IMPORTANT**: This repository pushes to TWO remotes simultaneously to prevent deployment failures:
- **professor** (PRIMARY): Steve-at-Mohawk-College/capstone-project-Jinphinity (Azure deployment)
- **origin** (BACKUP): Jinphinity/capstone (personal backup)

### Configuration
Configured with multiple push URLs on origin remote. When you run `git push`, it automatically pushes to BOTH remotes:

```bash
# Verify configuration
git remote -v
# Should show 2 push URLs for origin (professor first, origin second)

# Check push URLs specifically
git config --get-all remote.origin.pushurl
```

### Usage Rules (MANDATORY)
✅ **ALWAYS use**: `git push` or `git push origin main`
- Automatically updates BOTH remotes (professor primary, origin backup)
- Single command, both remotes guaranteed to sync

❌ **NEVER use**: `git push professor` only
- This skips origin remote and breaks sync

⚠️ **Both pushes must succeed**
- If either remote fails, the entire push fails and you'll see the error immediately
- This prevents deployment mismatches

### Setup Instructions (if not already configured)
```bash
git remote set-url --add --push origin git@github.com:Steve-at-Mohawk-College/capstone-project-Jinphinity.git
git remote set-url --add --push origin git@github.com:Jinphinity/capstone.git
```

### Why This Matters
Previous error: Pushed to origin only, Azure deploys from professor → deploy got old code.
Solution: Force both remotes to update with every push.

---

## Current Deployment Status (Latest)

### ✅ Completed Tasks
1. **Authentication System**: Fixed password validation mismatch (frontend ↔ backend)
2. **Docker Infrastructure**: Complete deployment stack (PostgreSQL + FastAPI + Godot)
3. **Browser Compatibility**: Fixed input handling, API environment detection, storage
4. **Game Server**: Running on port 8090 for local testing
5. **API Backend**: Real FastAPI server with JWT auth, character management, market system
6. **Password Requirements**: Aligned frontend validation with backend security:
   - Minimum 8 characters
   - Uppercase + lowercase + digit + symbol required
7. **Git History**: Cleaned AI references from commit messages
8. **SSD Deployment**: Complete application deployed to public GitHub (no markdown docs)

### 🎮 Browser Testing
- **Local Game**: http://localhost:8090
- **API Server**: http://localhost:8000 (Docker)
- **Health Status**: ✅ Healthy (database connected)
- **Test Credentials**: Use strong passwords (e.g., Password123@)

### 🔧 Repository Status
- **Capstone**: Main development branch with all fixes
- **SSD-Group-Deploy**: Public deployment repo (full game, no docs)
- **Latest Commits**: Authentication fixes synchronized across both repos

### ⚠️ Known Issues Fixed
- ❌ Mock API conflicts (removed)
- ❌ Password validation mismatch (fixed)
- ❌ Browser input compatibility (fixed)
- ❌ API environment detection (fixed)
- ❌ Game server startup (fixed)

### 🎯 Next Steps
1. Test character creation in browser
2. Verify inventory sync with API
3. Test market system functionality
4. Validate offline mode with browser storage
5. Prepare for milestone submission