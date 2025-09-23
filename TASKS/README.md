# Task Management System

This directory contains structured task management for Dizzy's Disease development.

## Directory Structure

```
TASKS/
├── README.md              # This file - task management overview
├── TEMPLATE.md            # Template for new tasks
├── active/                # Currently active tasks
├── completed/             # Completed tasks (archived)
├── blocked/               # Tasks waiting on dependencies
└── epic/                  # High-level epic tasks spanning multiple features
```

## Task States and Workflow

### Task States
- **active**: Currently being worked on
- **completed**: Successfully finished and archived
- **blocked**: Waiting on dependencies or external factors
- **epic**: High-level tasks broken down into smaller tasks

### Workflow Process
1. **Create**: Copy TEMPLATE.md to appropriate directory
2. **Activate**: Move to active/ when work begins
3. **Update**: Maintain progress updates and blockers
4. **Complete**: Move to completed/ with final summary
5. **Archive**: Update CHANGELOG.md with completed work

## Task Categories

### By Type
- **feature**: New functionality or capabilities
- **bugfix**: Fixing existing issues or problems
- **enhancement**: Improving existing features
- **research**: Investigation or proof-of-concept work
- **infrastructure**: Development tools and process improvements
- **compliance**: Academic requirement fulfillment

### By Priority
- **critical**: Blocking progress or security issues
- **high**: Important for current milestone
- **medium**: Valuable but not urgent
- **low**: Nice-to-have improvements

### By Scope
- **epic**: Multiple weeks, affects multiple systems
- **story**: 1-2 weeks, single feature or major component
- **task**: 1-3 days, specific implementation work
- **spike**: Research or investigation work

## Academic Compliance Integration

Tasks are categorized by academic requirement sections:

- **§1-5**: Foundation and setup
- **§6-10**: Core gameplay and progression
- **§11-15**: Advanced features and validation
- **§16-20**: Polish and optimization

Each task should reference relevant academic requirements and compliance criteria.

## Task Naming Convention

Format: `YYYY-MM-DD-[type]-[short-description].md`

Examples:
- `2024-01-15-feature-xp-system.md`
- `2024-01-16-bugfix-market-validation.md`
- `2024-01-17-compliance-error-handling.md`
- `2024-01-18-epic-ai-behavior-system.md`

## Task Dependencies

Track dependencies using:
- **depends_on**: Tasks that must complete first
- **blocks**: Tasks that are waiting on this task
- **related**: Tasks that share context or components

## Quality Gates

All tasks must meet quality requirements:
- ✅ **Functionality**: Feature works as specified
- ✅ **Testing**: Comprehensive test coverage
- ✅ **Documentation**: Updated docs and changelog
- ✅ **Security**: Security review completed
- ✅ **Performance**: Performance requirements met
- ✅ **Compliance**: Academic requirements satisfied

## Usage Examples

### Creating a New Task
```bash
cp TASKS/TEMPLATE.md TASKS/active/2024-01-20-feature-difficulty-presets.md
# Edit the file with task details
```

### Moving Task States
```bash
# When starting work
mv TASKS/blocked/task.md TASKS/active/

# When completing work
mv TASKS/active/task.md TASKS/completed/
```

### Epic Management
```bash
# Create epic with breakdown
cp TASKS/TEMPLATE.md TASKS/epic/2024-01-20-epic-ai-system.md
# Create child tasks referencing the epic
```

## Integration with Development Tools

### TodoWrite Integration
- Active tasks sync with Claude Code TodoWrite system
- Progress tracking maintains consistency across tools
- Completion triggers automatic archival

### Git Integration
- Task IDs reference in commit messages
- Branch naming follows task conventions
- PR descriptions link to relevant tasks

### CI/CD Integration
- Task completion triggers changelog updates
- Quality gate validation before task closure
- Automated task archival on successful deployment

---

*This task management system supports academic compliance and structured development workflow.*