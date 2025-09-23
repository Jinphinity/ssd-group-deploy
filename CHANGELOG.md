# Changelog

All notable changes to Dizzy's Disease will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive input validation framework (§15 Academic Compliance)
  - Client-side validation in MarketUI.gd with structured error logging
  - Server-side validation for all API endpoints with security event logging
  - Business rule validation for market transactions
  - Performance report validation with data integrity checks
  - Market event validation with comprehensive error handling

- Complete XP/Level-up system with weapon proficiencies (§6.1.1, §6.1.2)
  - 6 weapon proficiency categories affecting gameplay performance
  - Survivability stats (nourishment, sleep) with performance penalties
  - Performance multipliers for carry capacity, reload speed, movement, weapon sway
  - Health regeneration system based on endurance and nourishment

- Comprehensive error handling and structured logging (§14 Academic Compliance)
  - Exponential backoff retry logic with 7-stage delay sequence
  - Structured JSON logging with correlation IDs for request tracking
  - Security event logging for authentication and authorization events
  - Database error handling with proper categorization and recovery
  - Client-side error recovery with optimistic UI handling

- Comprehensive database seed data (§9 Academic Compliance)
  - 108 items across 6 weapon categories with balanced stats
  - 50+ NPC templates with diverse roles and attributes
  - 23 market events for dynamic economy simulation
  - Weapon proficiency columns added to characters table
  - Survivability stats integration with game progression

### Enhanced
- PlayerController.gd with complete progression system
  - Stat allocation system with 5 core attributes
  - Weapon proficiency tracking with XP-based progression
  - Performance multiplier calculations affecting gameplay
  - Enemy kill XP rewards with balanced progression curve

- MarketUI.gd with optimistic UI handling
  - Transaction state management with rollback capability
  - Stale transaction cleanup with 30-second timeout
  - Enhanced user feedback with color-coded status messages
  - Comprehensive input validation with business rule checks

- API error handling middleware
  - Request/response correlation ID tracking
  - Comprehensive validation exception handlers
  - Database connection error recovery
  - Security violation logging and monitoring

### Fixed
- Market transaction idempotency with X-Request-Id headers
- Database constraint violation handling
- Client-side transaction rollback on API failures
- Input validation error messages and user feedback

## [0.1.0] - 2024-01-XX - Foundation Release

### Added
- Initial Godot 4.4 project structure
- Perspective-agnostic camera system (FPS/TPS/Iso/Side)
- Basic player controller with movement
- Market system with buy/sell functionality
- Inventory management system
- Basic enemy AI and spawning
- Database schema with PostgreSQL backend
- FastAPI backend with authentication
- Basic UI components and scenes

### Infrastructure
- Docker containerization for development
- Database migrations system
- API documentation with OpenAPI/Swagger
- Basic testing framework setup
- Git repository structure with proper .gitignore

---

## Template for Future Releases

```markdown
## [X.Y.Z] - YYYY-MM-DD - Release Name

### Added
- New features and capabilities
- Academic compliance achievements (§ references)

### Changed
- Modifications to existing functionality
- Breaking changes with migration notes

### Enhanced
- Improvements to existing features
- Performance optimizations
- UX improvements

### Fixed
- Bug fixes with issue references
- Security vulnerability patches

### Deprecated
- Features marked for removal in future versions

### Removed
- Features removed in this version

### Security
- Security-related changes and improvements
```

---

## Academic Compliance Tracking

This project maintains compliance with academic requirements through structured development:

### Gate 1: Foundation (§1-5)
- ✅ Project setup and basic architecture
- ✅ Database schema and core entities
- ✅ Basic gameplay mechanics
- ✅ Initial API development

### Gate 2: Core Loop (§6-10)
- ✅ XP/Level-up system (§6.1.1, §6.1.2)
- ✅ Database seed data (§9 - ≥150 rows)
- ✅ Market dynamics and economy
- ✅ Basic combat and progression

### Gate 3: Features (§11-15)
- ✅ Error handling and logging (§14)
- ✅ Input validation framework (§15)
- 🚧 Live documentation workflow
- 🚧 CI/CD with provenance tracking
- ⏳ Advanced AI behaviors

### Gate 4: Polish (§16-20)
- ⏳ Difficulty presets system
- ⏳ Enhanced enemy AI
- ⏳ Security validation
- ⏳ Desktop export presets
- ⏳ Performance optimization

Legend: ✅ Complete | 🚧 In Progress | ⏳ Pending

## Development Workflow

All changes follow this structured process:

1. **Task Creation**: Document in TASKS/ directory with requirements
2. **Implementation**: Code with comprehensive testing and validation
3. **Review**: Quality gates including security and performance checks
4. **Documentation**: Update CHANGELOG.md with academic compliance tracking
5. **Decision Recording**: Create ADR for significant architectural decisions

## Contributors

- Claude Code AI Assistant - Implementation and academic compliance
- Development Team - Design, requirements, and human oversight

---

*This changelog is automatically maintained as part of the live documentation workflow.*