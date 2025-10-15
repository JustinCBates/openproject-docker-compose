# Complete OpenProject Docker Compose - Project Context

**Generated**: October 15, 2025  
**Current Branch**: `develop`  
**Purpose**: Complete system context and architecture refresh

---

## Executive Summary

The **OpenProject Docker Compose** project is undergoing a Python-based rebuild to replace Bash scripts with maintainable, testable Python code. The system uses a **multi-repository architecture** with **6 external Git submodules**, each providing specialized functionality that can be reused across projects.

### Current Status: Production-Ready Deploy-Manager ✅

The **deploy-manager** submodule has reached **100% completion** with:
- ✅ All 6 deployment phases implemented
- ✅ 28 library units complete
- ✅ Full CLI interface with rollback capability
- ✅ End-to-end testing validated
- ✅ ~8,350 lines of production-ready code

---

## Multi-Repository Architecture

```
openproject-docker-compose (Main Repository)
├── OpenProject-specific deployment logic
├── Maintenance operations (backup, upgrade, migrations)
├── CLI orchestration layer
└── External submodules (reusable components):
    ├── config-manager       (Interactive configuration)
    ├── deploy-manager       (Deployment orchestration) ✅ COMPLETE
    ├── prober               (Endpoint validation)
    ├── control-flow         (Flow visualization & execution)
    ├── dependency-manager   (Dependency tracking)
    └── tui-form-designer    (Terminal UI forms)
```

---

## Repository Breakdown

### 1. **openproject-docker-compose** (Main Repository)
**URL**: https://github.com/JustinCBates/openproject-docker-compose  
**Branch**: `develop` (30 commits ahead of origin)  
**Latest Commit**: `9a3218b` - Update deploy-manager submodule

**Purpose**: Main integration point for OpenProject deployment

**Structure**:
```
/opt/openproject/
├── docker-compose.yml              # Main orchestration
├── docker-compose.control.yml      # Backup/upgrade operations
├── .env.example                    # Environment template
├── openproject.code-workspace      # VS Code multi-repo workspace
├── production_manifest.yaml        # Production config spec
├── setup-dev-environment.sh        # Auto-setup script
├── docs/                           # Complete documentation
│   ├── architecture/               # System design
│   ├── design/                     # Workflow specs
│   ├── guides/                     # Dev/ops guides
│   ├── migration/                  # Rebuild progress
│   └── project/                    # Overview & structure
├── external/                       # Git submodules (6 repos)
│   ├── config-manager/
│   ├── deploy-manager/             ✅ COMPLETE
│   ├── prober/
│   ├── control-flow/
│   ├── dependency-manager/
│   └── tui-form-designer/
├── control/                        # Backup/upgrade scripts
├── proxy/                          # Caddy reverse proxy
├── src/                            # Python source (Phase 1 complete)
└── tests/                          # Test suite
```

**Key Features**:
- VS Code workspace with multi-repo support
- Automated dev environment setup
- Integrated tasks for testing, linting, formatting
- Submodule management automation

---

### 2. **config-manager** (External Submodule)
**URL**: https://github.com/JustinCBates/openproject-config-manager  
**Branch**: `develop`  
**Latest Commit**: `eca7789` - Field collection backlog tracking

**Purpose**: Interactive configuration management with discovery and validation

**Status**: 🏗️ Active Development
- Field collection system design complete
- Legacy config migration planned
- Discovery engine architecture designed

**Capabilities** (Planned):
- Auto-discover environment (OS, network, Docker, ports)
- Interactive terminal UI (Rich-based)
- Live validation with prober integration
- Generate `.env` and `.cfg` files

---

### 3. **deploy-manager** (External Submodule) ✅
**URL**: https://github.com/JustinCBates/openproject-deploy-manager  
**Branch**: `develop`  
**Latest Commit**: `786a927` - End-to-end test results documentation

**Purpose**: Production-ready deployment orchestration system

**Status**: ✅ **100% COMPLETE & VALIDATED**

**Implementation**:
```
deploy-manager/
├── cli/
│   ├── deploy_cli.py              # Complete CLI (6 commands)
│   └── README.md                  # Usage documentation
├── src/phases/
│   ├── phases_orchestrator.py     # Global orchestrator
│   ├── phase_1_preflight/         # Validation (6 steps)
│   ├── phase_2_template_rendering/# Template processing (4 steps)
│   ├── phase_3_snapshot/          # State capture (3 steps)
│   ├── phase_4_deployment/        # Docker deployment (4 steps)
│   ├── phase_5_health_verification/# Health checks (4 steps)
│   └── phase_6_post_deployment/   # Reporting/cleanup (3 steps)
├── libraries/                     # 28 reusable units
│   ├── config/ (5 units)          # Configuration management
│   ├── docker/ (7 units)          # Docker operations
│   ├── health/ (5 units)          # Health checking
│   ├── network/ (1 unit)          # Network utilities
│   ├── reporting/ (3 units)       # Status reporting
│   ├── snapshot/ (3 units)        # State management
│   ├── system/ (1 unit)           # System resources
│   └── templates/ (3 units)       # Jinja2 rendering
├── test_data/                     # Test fixtures
├── runtime/                       # Phase outputs
└── docs/                          # Complete docs
```

**CLI Commands**:
1. `deploy` - Full 6-phase deployment (with --cleanup flag)
2. `rollback` - 6-step recovery to snapshot
3. `health` - Run health verification
4. `status` - Show deployment history
5. `snapshot list` - List available snapshots
6. `snapshot show` - Show snapshot details

**Validation Results**:
- ✅ All 6 phases tested end-to-end
- ✅ Rollback capability verified
- ✅ Container health checks working
- ✅ Audit trail complete
- ✅ Path bug fixed (c50f13b)
- ✅ Cleanup flag added (9e71e30)

**Key Features**:
- **Idempotent operations** - Safe to retry
- **Automatic rollback** - On deployment failure
- **Health verification** - Containers, endpoints, databases
- **Snapshot management** - Capture & restore state
- **Complete audit trail** - All operations logged
- **CLI with safety features** - Confirmation prompts, dry-run mode

**Statistics**:
- **Total LOC**: ~8,350
- **Library Units**: 28/28 (100%)
- **Phases**: 6/6 (100%)
- **CLI Commands**: 6/6 (100%)
- **Test Coverage**: Integration + rollback tested
- **Production Ready**: ✅ Yes

---

### 4. **prober** (External Submodule)
**URL**: https://github.com/JustinCBates/docker_prober_utility  
**Branch**: `develop`  
**Latest Commit**: `931c89c` - Remove consolidated control flow files

**Purpose**: HTTP/HTTPS endpoint validation and testing

**Status**: ✅ Functional (Stable)

**Capabilities**:
- Test HTTP/HTTPS endpoints
- Validate TLS configuration
- Test reverse proxy URL rewriting
- Validate response headers and status codes
- Generate validation reports

**Used By**:
- config-manager (live validation during configuration)
- deploy-manager (preflight checks before deployment)

---

### 5. **control-flow** (External Submodule)
**URL**: https://github.com/JustinCBates/control-flow  
**Branch**: `develop`  
**Latest Commit**: `705ddd7` - Update scaffolder for runtime/ directories

**Purpose**: Control flow visualization and execution engine

**Status**: 🏗️ Active Development

**Capabilities**:
- Visual flow editor (TUI-based)
- Flow execution engine
- YAML-based flow specifications
- Runtime output management

---

### 6. **dependency-manager** (External Submodule)
**URL**: https://github.com/JustinCBates/dependency-manager  
**Branch**: `develop`  
**Latest Commit**: `1d55ad4` - Add .gitignore for Python cache

**Purpose**: Cross-repository dependency tracking

**Status**: 🏗️ Active Development

**Capabilities**:
- Track dependencies across repositories
- Detect dependency conflicts
- Generate dependency graphs
- Migration tracking

---

### 7. **tui-form-designer** (External Submodule)
**URL**: https://github.com/JustinCBates/TUI_Form_Designer  
**Branch**: `develop`  
**Latest Commit**: `8f8af92` - Add completion summaries

**Purpose**: Terminal UI form creation and management

**Status**: ✅ Functional

**Capabilities**:
- Rich-based terminal forms
- Field validation
- Form navigation (back/forward/skip)
- Resume capability

**Used By**:
- config-manager (interactive configuration UI)

---

## System Architecture

### Three-Manager Design

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLI Orchestration Layer                       │
│              (openproject-docker-compose main repo)             │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   ├─────────────────────┬─────────────────────────┐
                   ▼                     ▼                         ▼
         ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
         │ Config Manager  │   │ Deploy Manager  │   │ Maintenance Mgr │
         │  (external)     │   │  (external)     │   │  (main repo)    │
         ├─────────────────┤   ├─────────────────┤   ├─────────────────┤
         │ • Discovery     │   │ • Orchestration │   │ • Backup        │
         │ • Interactive   │   │ • Templates     │   │ • Upgrade       │
         │ • Validation    │   │ • Health Checks │   │ • Migrations    │
         │ • Uses Prober   │   │ • Rollback      │   │ • OpenProject   │
         │                 │   │ • Uses Prober   │   │   specific ops  │
         └─────────────────┘   └─────────────────┘   └─────────────────┘
                   │                     │
                   └──────────┬──────────┘
                              ▼
                   ┌─────────────────────┐
                   │  Prober Utility     │
                   │  (external)         │
                   ├─────────────────────┤
                   │ • HTTP/HTTPS test   │
                   │ • TLS validation    │
                   │ • Endpoint probing  │
                   │ • Recommendations   │
                   └─────────────────────┘
```

---

## Data Flow

### 1. Configuration Flow
```
Discovery → Interactive Collection → Validation → .env/.cfg Generation
    ↓              ↓                     ↓               ↓
  OS/Network    User Input          Prober Check    Files Created
```

### 2. Deployment Flow (deploy-manager)
```
Phase 1: Preflight Validation (6 steps)
  ├─ Load config
  ├─ Validate config
  ├─ Check Docker daemon
  ├─ Check port availability
  ├─ Run prober preflight
  └─ Validate system resources
        ↓
Phase 2: Template Rendering (4 steps)
  ├─ Extract template variables
  ├─ Render Caddyfile
  ├─ Render docker-compose.override.yml
  └─ Validate rendered templates
        ↓
Phase 3: Snapshot Creation (3 steps)
  ├─ Capture container states
  ├─ Backup configuration files
  └─ Store snapshot (with retention policy)
        ↓
Phase 4: Deployment Execution (4 steps)
  ├─ Generate environment file (.env)
  ├─ Pull Docker images
  ├─ Execute compose up
  └─ Monitor service startup
        ↓
Phase 5: Health Verification (4 steps)
  ├─ Check container health
  ├─ Probe HTTP/HTTPS endpoints
  ├─ Check database connectivity
  └─ Test service connectivity
        ↓
Phase 6: Post-Deployment (3 steps)
  ├─ Report deployment status
  ├─ Log deployment metadata
  └─ Cleanup temporary files
```

### 3. Rollback Flow (deploy-manager)
```
Step 1: Load Snapshot
Step 2: Stop Current Deployment
Step 3: Restore Configuration Files
Step 4: Restart Services
Step 5: Verify Health
Step 6: Log Rollback Event
```

---

## Development Status

### Phase 1: Core Utilities ✅ COMPLETE
- ✅ Configuration manager (basic)
- ✅ Python project structure
- ✅ CLI framework
- ✅ Unit tests (97% coverage)

### Phase 2: Deploy-Manager ✅ COMPLETE
- ✅ All 6 deployment phases
- ✅ 28 library units
- ✅ Rollback capability
- ✅ CLI interface
- ✅ End-to-end testing
- ✅ Production validation

### Phase 3: Config-Manager 🏗️ IN PROGRESS
- 🏗️ Interactive configuration system
- 🏗️ Discovery engine
- 🏗️ Field collection
- 📋 Validation engine design

### Phase 4: Control Plane 📋 PLANNED
- 📋 Backup manager (Python)
- 📋 Upgrade manager (Python)
- 📋 Migration manager

### Phase 5: Integration 📋 PLANNED
- 📋 Full workflow: config → deploy → maintain
- 📋 Multi-manager orchestration
- 📋 Comprehensive testing

---

## Key Documentation

### Architecture & Design
- `docs/architecture/ARCHITECTURE.md` - System architecture (1,176 lines)
- `docs/architecture/INTERACTIVE_CONFIG_ARCHITECTURE.md` - Config system design
- `docs/design/CONFIG_VARIABLE_FLOW.md` - Configuration flow

### Project Overview
- `docs/project/PROJECT_OVERVIEW.md` - Complete project overview (406 lines)
- `docs/project/MULTI_REPO_SUMMARY.md` - Multi-repo structure (321 lines)
- `docs/project/PROJECT_STRUCTURE_MASTER.md` - Master reference
- `docs/project/BRANCH_RESTRUCTURE_COMPLETE.md` - Branch status
- `docs/project/DEPENDENCY_ANALYSIS.md` - Cross-repo dependencies

### Migration & Progress
- `docs/migration/MIGRATION_PLAN.md` - Comprehensive migration strategy
- `docs/migration/PYTHON_REBUILD.md` - Rebuild phases and progress

### Guides
- `docs/guides/SUBMODULES_GUIDE.md` - Git submodule workflows
- `docs/guides/MANAGER_FOLDERS.md` - Manager component organization

### Deploy-Manager Documentation
- `external/deploy-manager/cli/README.md` - CLI usage guide
- `external/deploy-manager/END_TO_END_TEST_RESULTS.md` - Test validation
- Phase-specific READMEs in each phase directory

---

## VS Code Workspace

The project includes a comprehensive VS Code workspace configuration:

**File**: `openproject.code-workspace`

**Features**:
- Multi-repository folder support (7 folders)
- Python development settings
- Integrated linting (flake8)
- Auto-formatting (black)
- Git submodule detection
- Built-in tasks (test, format, lint, submodule management)
- Debug configurations

**Available Tasks**:
- Run Tests (All Repos)
- Format Code (Black - All Repos)
- Lint Code (Flake8 - All Repos)
- Update Submodules
- Initialize Submodules (First Time Setup)
- Switch All Submodules to Main Branch

---

## Technology Stack

### Languages & Frameworks
- **Python 3.8+** - Primary language
- **Bash** - Legacy scripts (being replaced)
- **YAML** - Configuration files
- **Jinja2** - Template rendering

### Python Dependencies
- **click** - CLI framework
- **rich** - Terminal UI
- **python-dotenv** - Environment files
- **pyyaml** - YAML parsing
- **docker** - Docker SDK
- **jinja2** - Template engine

### Development Tools
- **pytest** - Testing framework
- **black** - Code formatting
- **flake8** - Linting
- **mypy** - Type checking (optional)
- **coverage** - Test coverage

### Infrastructure
- **Docker Engine 20.10+**
- **Docker Compose 2.0+**
- **Git 2.x**
- **PostgreSQL 13** (for OpenProject)
- **Caddy 2.x** (reverse proxy)

---

## Testing Strategy

### Unit Testing
- **Each repository has its own test suite**
- **Target coverage**: ≥80%
- **CI/CD**: Runs on every push/PR

### Integration Testing
- **Main repo**: Full workflow tests
- **Scenarios**: HTTP, HTTPS, namespace, different configs
- **End-to-end**: config → deploy → backup → upgrade

### Validation
- **deploy-manager**: Fully tested end-to-end ✅
- **Rollback**: Verified working ✅
- **Health checks**: Validated ✅
- **Audit trail**: Complete ✅

---

## Recent Achievements

### Deploy-Manager (October 2025)
- ✅ Completed all 6 deployment phases
- ✅ Implemented 28 library units (~8,350 LOC)
- ✅ Created comprehensive CLI with 6 commands
- ✅ Added rollback capability (6-step recovery)
- ✅ End-to-end testing validated
- ✅ Fixed path doubling bug (c50f13b)
- ✅ Added --cleanup flag (9e71e30)
- ✅ Documented complete test results
- ✅ Production-ready status achieved

### Recent Commits (Main Repo)
```
9a3218b - chore: update deploy-manager submodule
fafd193 - Update submodule: add scaffolding summary
8c7422a - Update submodule: deploy-manager scaffolding complete
d434d11 - Update submodules: deploy-manager spec complete, control-flow bugs fixed
```

---

## How Components Interact

### Example: Full Deployment Workflow

1. **User runs**: `openproject deploy`
   
2. **CLI orchestrates**:
   ```
   → Load config (config-manager)
   → Validate environment (config-manager + prober)
   → Render templates (deploy-manager)
   → Execute deployment (deploy-manager)
   → Verify health (deploy-manager + prober)
   → Generate reports (deploy-manager)
   → Log metadata (deploy-manager)
   ```

3. **Artifacts created**:
   - `.env.production` (environment variables)
   - `Caddyfile` (rendered proxy config)
   - `docker-compose.override.yml` (rendered overrides)
   - `snap_project_timestamp.json` (snapshot)
   - `deployment_report.json` (status report)
   - `deployment_history.log` (audit trail)

4. **Containers deployed**:
   - `project-web-1` (OpenProject app)
   - `project-db-1` (PostgreSQL)
   - `project-cache-1` (Memcached)
   - `project-proxy-1` (Caddy)
   - `project-worker-1` (background jobs)
   - `project-cron-1` (scheduled tasks)

5. **Health verified**:
   - Container health checks
   - HTTP/HTTPS endpoint tests
   - Database connectivity
   - Service responsiveness

6. **Result**:
   - Deployment successful or rolled back
   - Complete audit trail logged
   - Snapshot available for rollback

---

## Next Steps

### Immediate Priorities

1. **Complete config-manager** (Phase 3)
   - Implement discovery engine
   - Build interactive UI
   - Add validation with prober integration
   - Generate configuration files

2. **Integrate deploy-manager** (Phase 4)
   - Update main repo dependencies
   - Wire CLI to use external deploy-manager
   - Test full integration
   - Document workflow

3. **Build maintenance manager** (Phase 5)
   - Port backup scripts to Python
   - Port upgrade scripts to Python
   - Add migration support
   - Create CLI commands

4. **Full system testing** (Phase 6)
   - End-to-end workflow testing
   - Multi-scenario validation
   - Performance benchmarking
   - Documentation updates

---

## Success Metrics

### Deploy-Manager: ✅ Complete
- [x] All phases implemented (6/6)
- [x] All library units complete (28/28)
- [x] CLI functional (6/6 commands)
- [x] Rollback tested and working
- [x] End-to-end validation passed
- [x] Production-ready

### Config-Manager: 🏗️ In Progress
- [ ] Discovery engine implemented
- [ ] Interactive UI complete
- [ ] Validation with prober
- [ ] Configuration generation
- [ ] Integration tested

### Maintenance Manager: 📋 Planned
- [ ] Backup manager implemented
- [ ] Upgrade manager implemented
- [ ] Migration manager implemented
- [ ] CLI commands added
- [ ] Testing complete

### Overall System: 🏗️ In Progress
- [x] Multi-repo architecture established
- [x] Deploy-manager production-ready
- [ ] Config-manager complete
- [ ] Maintenance manager complete
- [ ] Full integration tested
- [ ] Documentation comprehensive

---

## Contributing

See individual repository README files for contribution guidelines.

**Main Repo Guidelines**:
- Follow PEP 8 for Python code
- Use type hints for function signatures
- Write docstrings for all public functions
- Maintain ≥80% test coverage
- Update documentation with changes

---

## Resources

### Repositories
- Main: https://github.com/JustinCBates/openproject-docker-compose
- Config: https://github.com/JustinCBates/openproject-config-manager
- Deploy: https://github.com/JustinCBates/openproject-deploy-manager
- Prober: https://github.com/JustinCBates/docker_prober_utility
- Control-Flow: https://github.com/JustinCBates/control-flow
- Dependency: https://github.com/JustinCBates/dependency-manager
- TUI Forms: https://github.com/JustinCBates/TUI_Form_Designer

### Documentation
- Architecture: `/opt/openproject/docs/architecture/ARCHITECTURE.md`
- Migration Plan: `/opt/openproject/docs/migration/MIGRATION_PLAN.md`
- Project Overview: `/opt/openproject/docs/project/PROJECT_OVERVIEW.md`

---

**Last Updated**: October 15, 2025  
**Maintained By**: Development Team  
**Status**: Living Document (Updated with each major milestone)
