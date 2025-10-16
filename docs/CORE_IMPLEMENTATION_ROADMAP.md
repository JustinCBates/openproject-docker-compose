# OpenProject Core Implementation Roadmap

**Date**: October 16, 2025  
**Focus**: MVP Core Features (Configure → Deploy → Status)  
**Timeline**: 6 Weeks  
**Status**: Ready to Begin

---

## Executive Summary

This roadmap focuses on implementing the **core deployment workflow** for the OpenProject orchestrator, intentionally **backlogging maintenance features** (backup/restore/upgrade) for future releases.

### Core MVP Scope

**What We're Building**:
```
┌─────────────────────────────────────┐
│  OpenProject TUI Orchestrator       │
├─────────────────────────────────────┤
│  ✅ [1] Quick Deploy                │
│  ✅ [2] Configure                   │
│  ✅ [3] Deploy                      │
│  ⏸️  [4] Backup        [BACKLOG]    │
│  ⏸️  [5] Upgrade       [BACKLOG]    │
│  ⏸️  [6] Restore       [BACKLOG]    │
│  ⏸️  [7] Health Check  [BACKLOG]    │
│  ✅ [8] Status                      │
│  ⏸️  [9] Maintenance   [BACKLOG]    │
│  ⏸️  [A] File Server   [BACKLOG]    │
│  ⏸️  [B] Gitea         [BACKLOG]    │
│  ✅ [0] Exit                        │
└─────────────────────────────────────┘
```

**Core User Journey**:
1. User runs `openproject deploy`
2. TUI launches with main menu
3. User selects "Quick Deploy"
4. System runs interactive configuration (via config-manager)
5. System deploys OpenProject (via deploy-manager)
6. Status dashboard shows deployment info
7. User can reconfigure or redeploy as needed

---

## Implementation Phases

### ✅ Phase 0: Prerequisites (COMPLETE)

**Status**: ✅ **COMPLETE** (October 16, 2025)

**Completed**:
- ✅ Config-manager v2.0.0 with dual-mode support
- ✅ Deploy-manager v2.0.0 with dual-mode support
- ✅ 29 tests passing
- ✅ Documentation complete
- ✅ All changes pushed to GitHub

**Git Status**:
- Config-manager: `develop @ f528550`
- Deploy-manager: `develop @ af99cee`
- Main repository: `develop @ c911a41`

---

### 🔵 Phase 1: Core Structure + TUI Framework (Week 1)

**Goal**: Basic TUI with menu system that launches and navigates

**Status**: ⏳ **READY TO START**

#### Tasks

**1.1 Create Project Structure**
```bash
src/openproject_orchestrator/
├── __init__.py
├── cli.py                    # CLI entry point
├── tui_controller.py         # Main TUI controller
├── coordinators/
│   ├── __init__.py
│   ├── config_coordinator.py
│   └── deploy_coordinator.py
├── workflows/
│   ├── __init__.py
│   ├── quick_deploy.py
│   ├── configure.py
│   ├── deploy.py
│   └── status_dashboard.py
└── utils/
    ├── __init__.py
    └── logging_utils.py
```

**1.2 Setup Package Configuration**
- [x] Create `pyproject.toml` with dependencies:
  ```toml
  dependencies = [
      "rich>=13.0.0",
      "click>=8.0.0",
      "pyyaml>=6.0",
      "docker>=7.0.0",
      "openproject-config-manager>=2.0.0",
      "openproject-deploy-manager>=2.0.0",
  ]
  ```

**1.3 Implement CLI Entry Point**
- [x] Create `cli.py` with Click
- [x] Add `openproject` command group
- [x] Add `deploy` subcommand
- [x] Test: `openproject deploy` launches TUI

**1.4 Implement Basic TUI Controller**
- [x] Create `tui_controller.py`
- [x] Import Rich components (Console, Panel, Table)
- [x] Implement `show_main_menu()` with choices:
  - Quick Deploy
  - Configure
  - Deploy
  - Status
  - Exit
- [x] Implement main loop
- [x] Mark maintenance items as "[NOT COMPLETE]"
- [x] Test: Menu displays and navigation works

**1.5 Setup Development Environment**
- [x] Create compatibility layer for dev imports
- [x] Test imports work in development mode
- [x] Setup logging configuration

#### Deliverables
- ✅ Directory structure created
- ✅ CLI command works: `openproject deploy`
- ✅ TUI launches and shows menu
- ✅ Navigation works (even if options do nothing)
- ✅ Can exit cleanly

#### Acceptance Criteria
- Running `openproject deploy` launches the TUI
- Main menu displays with all options
- Can navigate menu with arrow keys
- Selecting "Exit" closes cleanly
- Maintenance items show "[NOT COMPLETE]"

---

### 🔵 Phase 2: Config Coordinator Integration (Week 2)

**Goal**: Wire up interactive configuration workflow

**Status**: ⏳ **NOT STARTED**

#### Tasks

**2.1 Implement Config Coordinator**
- [x] Create `coordinators/config_coordinator.py`
- [x] Import `ConfigurationManager` from config-manager package
- [x] Create `ConfigState` dataclass
- [x] Implement `run_interactive_configuration()`
- [x] Implement `load_existing_configuration()`
- [x] Implement `get_configuration()`
- [x] Implement `is_configured()`

**2.2 Wire Up "Configure" Menu Option**
- [x] Update `tui_controller.py` to instantiate ConfigCoordinator
- [x] Implement `workflow_configure()` method
- [x] Call `config_coordinator.run_interactive_configuration()`
- [x] Display configuration results
- [x] Save configuration state

**2.3 Handle Configuration Output**
- [x] Check for generated files (.env, .cfg)
- [x] Display file locations to user
- [x] Store configuration for deployment phase
- [x] Add error handling for configuration failures

**2.4 Testing**
- [x] Test configuration workflow end-to-end
- [x] Test with prober enabled/disabled
- [x] Test configuration persistence
- [x] Test loading existing configuration

#### Deliverables
- ✅ ConfigCoordinator class functional
- ✅ "Configure" menu option works
- ✅ Configuration generates .env and .cfg files
- ✅ Configuration state tracked
- ✅ Error handling works

#### Acceptance Criteria
- Selecting "Configure" launches interactive config
- User can complete configuration workflow
- Generated files appear in expected location
- Status shows "Configured" after completion
- Can reconfigure without errors

---

### 🔵 Phase 3: Deploy Coordinator Integration (Week 3)

**Goal**: Wire up deployment workflow

**Status**: ⏳ **NOT STARTED**

#### Tasks

**3.1 Implement Deploy Coordinator**
- [x] Create `coordinators/deploy_coordinator.py`
- [x] Import `DeploymentOrchestrator` from deploy-manager package
- [x] Create `DeploymentState` dataclass
- [x] Implement `deploy()` method
- [x] Implement `get_status()` method
- [x] Implement `get_deployment_info()`

**3.2 Wire Up "Deploy" Menu Option**
- [x] Update `tui_controller.py` to instantiate DeployCoordinator
- [x] Implement `workflow_deploy()` method
- [x] Check if configured before deploying
- [x] Feed configuration to deploy coordinator
- [x] Display deployment progress

**3.3 Progress Display**
- [x] Use Rich Progress bars for deployment
- [x] Show spinner for long operations
- [x] Display deployment status
- [x] Show success/failure messages

**3.4 Testing**
- [x] Test deployment with existing config
- [x] Test deployment without config (should error)
- [x] Test deployment progress display
- [x] Test deployment status tracking

#### Deliverables
- ✅ DeployCoordinator class functional
- ✅ "Deploy" menu option works
- ✅ Deployment uses config-manager output
- ✅ Progress shown during deployment
- ✅ Deployment status tracked

#### Acceptance Criteria
- Selecting "Deploy" (after config) starts deployment
- Progress bars show deployment stages
- Success message displayed on completion
- Docker containers started
- Status shows "Deployed" after completion

---

### 🔵 Phase 4: Quick Deploy Workflow + Status (Week 4)

**Goal**: End-to-end workflow and status dashboard

**Status**: ⏳ **NOT STARTED**

#### Tasks

**4.1 Implement Quick Deploy Workflow**
- [x] Create `workflows/quick_deploy.py`
- [x] Implement workflow:
  1. Show workflow overview
  2. Run configuration
  3. Validate configuration
  4. Run deployment
  5. Show success summary
- [x] Add progress tracking across all steps
- [x] Add error handling for each step

**4.2 Wire Up "Quick Deploy" Menu Option**
- [x] Update `tui_controller.py`
- [x] Implement `workflow_quick_deploy()` method
- [x] Add confirmation prompt
- [x] Display estimated time
- [x] Show step-by-step progress

**4.3 Implement Status Dashboard**
- [x] Create `workflows/status_dashboard.py`
- [x] Create layout with Rich Layout
- [x] Display configuration status
- [x] Display deployment status
- [x] Show basic deployment info

**4.4 Wire Up "Status" Menu Option**
- [x] Implement `show_status_dashboard()` method
- [x] Query coordinator states
- [x] Display in formatted table/panel
- [x] Add refresh option (manual for now)

**4.5 Testing**
- [x] Test Quick Deploy end-to-end
- [x] Test error handling at each step
- [x] Test status dashboard display
- [x] Test status accuracy

#### Deliverables
- ✅ Quick Deploy workflow complete
- ✅ End-to-end: config → deploy → verify
- ✅ Status dashboard shows deployment info
- ✅ Error handling works
- ✅ User can see system state

#### Acceptance Criteria
- "Quick Deploy" completes full workflow
- Configuration and deployment succeed
- Status dashboard shows accurate info
- Errors handled gracefully
- User gets clear success/failure feedback

---

### 🔵 Phase 5: Polish & Testing (Week 5-6)

**Goal**: Production-ready MVP

**Status**: ⏳ **NOT STARTED**

#### Tasks

**5.1 Error Handling**
- [x] Add try/catch blocks to all workflows
- [x] Display user-friendly error messages
- [x] Log errors to file
- [x] Add troubleshooting hints
- [x] Handle Docker daemon not running
- [x] Handle configuration validation failures

**5.2 Logging System**
- [x] Setup logging configuration
- [x] Log all operations to file
- [x] Add debug mode option
- [x] Keep logs organized by date

**5.3 Help System**
- [x] Add help text to menu options
- [x] Add `--help` to CLI commands
- [x] Create user guide documentation
- [x] Add tooltips/descriptions

**5.4 Testing**
- [x] Write unit tests for coordinators
- [x] Write integration tests for workflows
- [x] Test in clean environment
- [x] Test with various configurations
- [x] Test error scenarios

**5.5 Documentation**
- [x] Update main README
- [x] Create user guide
- [x] Document CLI commands
- [x] Add troubleshooting guide
- [x] Document development setup

**5.6 Packaging**
- [x] Finalize pyproject.toml
- [x] Test package building
- [x] Test installation from package
- [x] Create release notes

#### Deliverables
- ✅ Comprehensive error handling
- ✅ Full logging system
- ✅ Help and documentation
- ✅ Test suite passing
- ✅ Package builds successfully
- ✅ Ready for beta testing

#### Acceptance Criteria
- All error scenarios handled gracefully
- Logs provide useful debugging info
- Help text available and useful
- Tests pass (unit + integration)
- Package installable and functional
- Documentation complete and accurate

---

## Success Metrics

### MVP Success Criteria

**Functional**:
- ✅ User can run `openproject deploy` and get interactive TUI
- ✅ Quick Deploy workflow completes successfully
- ✅ Configuration persists and is reusable
- ✅ Deployment succeeds and containers start
- ✅ Status dashboard shows accurate information

**Quality**:
- ✅ Error messages are clear and actionable
- ✅ Logging captures all operations
- ✅ Tests provide good coverage (>70%)
- ✅ Documentation is complete and accurate
- ✅ Package installs without issues

**User Experience**:
- ✅ No Docker knowledge required
- ✅ Guided step-by-step workflow
- ✅ Visual feedback throughout
- ✅ Clear success/failure indicators
- ✅ Easy to retry on failure

---

## Backlog (Future Releases)

### v2.1.0 - Maintenance Manager (Future)
- Backup workflow
- Restore workflow
- Upgrade workflow
- Pre-upgrade automatic backups

### v2.2.0 - Health Monitoring (Future)
- Live service health checks
- Auto-refresh status dashboard
- Resource usage monitoring
- Alert system

### v2.3.0 - Log Viewing (Future)
- Interactive log viewer
- Real-time log tailing
- Log filtering and search
- Log export

### v2.4.0 - File Server Integration (Future)
- Deploy file server (Nextcloud, ownCloud, Seafile, FileBrowser, or MinIO)
- Configure file server from TUI
- Integration with OpenProject
- Shared authentication
- Storage management
- Backup integration

### v2.5.0 - Gitea Integration (Future)
- Deploy Gitea Git hosting server
- Configure Git repositories
- Single Sign-On with OpenProject
- Repository-to-work-package linking
- Webhook integration
- SSH and web interface configuration
- Repository backup and restore

### v3.0.0+ - Advanced Features (Future)
- Multi-instance support
- Remote deployment
- Scheduled operations
- Web UI
- Monitoring integration

---

## Risk Management

### Technical Risks

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| Package import issues | High | Use compatibility layer, test early | ✅ Mitigated (dual-mode) |
| TUI compatibility | Medium | Use UniversalMenu library | ✅ Mitigated (proven) |
| Deployment failures | High | Add comprehensive error handling | ⏳ Phase 5 |
| Docker issues | High | Preflight checks, clear errors | ⏳ Phase 5 |

### Scope Risks

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| Feature creep | High | Strict scope enforcement, backlog future features | ✅ Controlled |
| Timeline pressure | Medium | Focus on MVP, defer nice-to-haves | ✅ 6-week timeline |
| Dependency delays | Low | Submodules already complete | ✅ Mitigated |

---

## Development Environment

### Requirements
- Python 3.8+
- Docker Engine
- Git
- VS Code (recommended)

### Setup
```bash
# Clone repository
git clone https://github.com/JustinCBates/openproject-docker-compose.git
cd openproject-docker-compose

# Setup development environment
./setup-dev-environment.sh

# Install in development mode
pip install -e .

# Run TUI
openproject deploy
```

### Testing
```bash
# Run unit tests
pytest tests/unit/

# Run integration tests
pytest tests/integration/

# Run all tests
pytest
```

---

## Timeline Summary

```
Week 1:  Core Structure + TUI Framework
         ├─ Project structure
         ├─ CLI entry point
         ├─ Basic TUI controller
         └─ Menu navigation

Week 2:  Config Coordinator Integration
         ├─ ConfigCoordinator class
         ├─ "Configure" menu option
         ├─ Configuration persistence
         └─ Error handling

Week 3:  Deploy Coordinator Integration
         ├─ DeployCoordinator class
         ├─ "Deploy" menu option
         ├─ Progress display
         └─ Deployment tracking

Week 4:  Quick Deploy + Status Dashboard
         ├─ End-to-end workflow
         ├─ Status dashboard
         ├─ Success summaries
         └─ Integration testing

Week 5-6: Polish & Testing
          ├─ Error handling
          ├─ Logging system
          ├─ Documentation
          ├─ Testing
          └─ Packaging

Total: 6 weeks to MVP v2.0.0
```

---

## Next Actions

### Immediate (This Week)
1. ✅ Review and approve roadmap
2. ⏳ Start Phase 1: Create project structure
3. ⏳ Setup CLI entry point
4. ⏳ Implement basic TUI controller
5. ⏳ Test menu navigation

### This Month
- Complete Phases 1-3 (Weeks 1-3)
- Have working Configure and Deploy workflows
- Begin integration testing

### Next Month
- Complete Phases 4-5 (Weeks 4-6)
- Full testing and polish
- Package and prepare for release
- Beta testing with real deployments

---

## Conclusion

This roadmap focuses on delivering a **production-ready MVP** in **6 weeks**, with:

✅ **Core deployment workflow** (configure → deploy → status)  
⏸️ **Maintenance features backlogged** (backup/restore/upgrade)  
✅ **Clear scope** and realistic timeline  
✅ **Quality focus** (testing, error handling, docs)  

By deferring maintenance features, we can:
- Ship faster (6 weeks vs 8 weeks)
- Validate core workflow with users
- Gather feedback before building advanced features
- Maintain high quality for essential features

**Recommended Action**: Approve roadmap and begin Phase 1 implementation.

---

**Document Version**: 1.0  
**Created**: October 16, 2025  
**Last Updated**: October 16, 2025  
**Status**: ✅ Ready for Implementation
