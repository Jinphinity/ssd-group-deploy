# Capstone Project - GODOT-AEGIS Integration

## Project Context
This is a Godot 4.4 game project called "Capstone" - a disease simulation game with multiplayer components, complex AI systems, and cross-platform deployment requirements.

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