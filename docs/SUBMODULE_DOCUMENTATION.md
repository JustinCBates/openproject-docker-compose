# Submodule Documentation Index

**Purpose**: Central index for navigating implementation documentation across all 6 submodules  
**Last Updated**: October 16, 2025

---

## Quick Navigation

| Submodule | Primary Docs | Implementation Status |
|-----------|--------------|----------------------|
| [Config-Manager](#config-manager) | 1 comprehensive doc | ✅ Phase 5 Complete |
| [Deploy-Manager](#deploy-manager) | 11 docs (proposal + progress) | 🔄 Phase 4 In Progress |
| [Control-Flow](#control-flow) | 7 consolidated docs | ✅ Production Ready |
| [Prober](#prober) | (Check submodule) | ✅ Standalone Utility |
| [Dependency-Manager](#dependency-manager) | README + Migration Log | ✅ Functional |
| [TUI-Form-Designer](#tui-form-designer) | (Check submodule) | ✅ Functional |

---

## Config-Manager

**Path**: `external/config-manager/docs/`  
**Purpose**: Interactive configuration system for Docker Compose projects  
**Integration Guide**: [CONTROL_FLOW_INTEGRATION.md](project/CONTROL_FLOW_INTEGRATION.md)

### Primary Documentation

#### CONFIG_MANAGER_IMPLEMENTATION.md (1,052 lines)
**Status**: ✅ **Canonical Implementation Reference**  
**Use This For**: Understanding current system, development, architecture

**Contents**:
- System Overview - What config-manager does today
- Architecture - 5-phase control-flow based workflow
- Phase Implementations:
  - Phase 1: Discovery (auto-detect system environment)
  - Phase 2: TUI Mapping (transform data for terminal UI)
  - Phase 3: Collection (interactive user configuration)
  - Phase 4: Validation (validate completeness)
  - Phase 5: Export (generate deployment files)
- Libraries & Units - Shared components
- File Locations - Complete directory structure
- Data Flow - YAML workflow specifications
- Current Status - Implementation progress
- Development Guide - How to modify the system

**Key Sections**:
- Directory structure with actual file paths
- Libraries: `probing/` (docker_detector.py, network_detector.py, system_detector.py)
- Control flow YAML: `design_specs/control_flows.yml`
- Output files: enhanced_defaults.yml, tui_defaults.yml, user_configuration.yml

---

## Deploy-Manager

**Path**: `external/deploy-manager/docs/`  
**Purpose**: Deployment orchestration for Docker Compose stacks  
**Integration Guide**: [CONTROL_FLOW_INTEGRATION.md](project/CONTROL_FLOW_INTEGRATION.md)

### Primary Documentation

#### DEPLOY_MANAGER_PROPOSAL.md (542 lines)
**Status**: ✅ **Original Design Proposal**  
**Use This For**: Understanding component architecture and design rationale

**Contents**:
- Component Overview - Deployment orchestration goals
- Main Components:
  - Deployment Orchestrator (core controller)
  - Configuration Loader (load from config-manager)
  - Template Renderer (Jinja2 templates)
  - Docker Client Wrapper (Docker SDK interface)
- Complete method signatures
- Template support (Caddyfile.j2, nginx.conf.j2, docker-compose.override.yml.j2)
- Flow orchestration details

#### IMPLEMENTATION_PROGRESS.md (377 lines)
**Status**: 🔄 **Current Implementation Tracking**  
**Use This For**: Understanding what's implemented, what's pending

**Contents**:
- Phase 1: Critical Library Units (✅ COMPLETE - 6 units)
  - Config domain: config_loader.py, config_validator.py
  - Docker domain: docker_checker.py
- Test results with actual commit references
- Implementation status by domain
- Next steps and pending work

#### Other Progress Documents

| Document | Purpose | Lines |
|----------|---------|-------|
| PHASE_1_COMPLETE.md | Phase 1 completion summary | - |
| PHASE_2A_SUMMARY.md | Phase 2A work summary | - |
| PROGRESS_REPORT.md | Overall progress tracking | - |
| SCAFFOLDING_SUMMARY.md | Initial scaffolding details | - |
| SCAFFOLDING_V2_SUMMARY.md | Scaffolding v2 improvements | - |
| SESSION_SUMMARY_PHASE4.md | Phase 4 session notes | - |
| VALIDATION_REPORT.md | Validation testing results | - |
| FLOW_EDITOR_FIXES.md | Flow editor bug fixes | - |
| FLOW_EDITOR_USER_TEST.md | User testing results | - |

---

## Control-Flow

**Path**: `external/control-flow/docs/`  
**Purpose**: Universal workflow orchestration engine (used by all repos)  
**Integration Guide**: [CONTROL_FLOW_INTEGRATION.md](project/CONTROL_FLOW_INTEGRATION.md)

### Primary Documentation

#### DOCUMENTATION_INDEX.md
**Status**: ✅ **Main Entry Point**  
**Use This For**: Navigating all control-flow documentation

**Contents**:
- Quick start guide
- Documentation structure overview
- Links to all 7 core documents

#### LIBRARY_ARCHITECTURE.md
**Status**: ✅ **Universal Libraries Reference**  
**Use This For**: Understanding the 13 universal libraries (~6,850 LOC)

**Contents**:
- Complete library catalog
- Integration patterns
- Usage examples
- Cross-repository benefits

**Libraries Documented**:
- File System Libraries (7): directory management, config files, paths, archives
- Container Libraries (3): Docker SDK wrappers, container management
- User Interface Libraries (3): interactive UI, terminal capabilities, questionary fallback

#### IMPLEMENTATION_SUMMARY.md
**Status**: ✅ **Implementation Details**  
**Use This For**: Understanding implementation history and key features

**Contents**:
- Phase 1: Core Libraries (7 universal libraries)
- Phase 2: UI Libraries (arrow-key bug fix, interactive UI)
- Critical bug fixes documented
- Move/reorder feature implementation

#### Other Core Documents

| Document | Purpose |
|----------|---------|
| FLOW_EDITOR_GUIDE.md | How to use the flow editor |
| LIBRARY_DEVELOPMENT_GUIDE.md | Creating new universal libraries |
| SCAFFOLDING_GUIDE.md | Code generation from YAML specs |
| VISUALIZATION_GUIDE.md | Graphviz diagram generation |

**Cleanup History**: Consolidated from 16 files → 7 files (October 16, 2025)

---

## Prober

**Path**: `external/prober/docs/`  
**Purpose**: HTTP/HTTPS endpoint validation utility  
**Status**: ✅ Standalone utility (reusable)

### Documentation Status
**Action Required**: Check `external/prober/docs/` for documentation  
**Integration**: Used by config-manager and deploy-manager for validation

**Expected Docs**:
- HTTP/HTTPS endpoint testing
- TLS validation
- Reverse proxy testing
- Response header validation

---

## Dependency-Manager

**Path**: `external/dependency-manager/`  
**Purpose**: Dependency management and installation  
**Status**: ✅ Functional

### Primary Documentation

#### README.md
**Status**: ✅ **Main Reference**  
**Use This For**: Understanding dependency management system

#### MIGRATION_LOG.md
**Status**: ✅ **Historical Record**  
**Use This For**: Understanding migration history and changes

**Related Files**:
- `demo_dependency_manager.py` - Usage examples
- `test_dependency_manager.py` - Test suite
- `scripts/check_deps.sh` - Dependency checking
- `scripts/install_deps.py` - Installation automation

---

## TUI-Form-Designer

**Path**: `external/tui-form-designer/docs/`  
**Purpose**: Terminal UI form designer and validator  
**Status**: ✅ Functional

### Documentation Status
**Action Required**: Check `external/tui-form-designer/docs/` for documentation

**Known Issues Fixed**:
- ✅ Arrow-key bug (fixed via control-flow Interactive UI Library)
- Same solution as control-flow flow-editor

**Expected Docs**:
- Form design system
- Validator architecture
- TUI component library
- Integration with control-flow Interactive UI

---

## Cross-Repository Documentation

### Integration Guides

**Main Repository Documentation**:
- [CONTROL_FLOW_INTEGRATION.md](project/CONTROL_FLOW_INTEGRATION.md) - How control-flow integrates everywhere
- [ARCHITECTURE.md](architecture/ARCHITECTURE.md) - Multi-repository architecture
- [SUBMODULES_GUIDE.md](guides/SUBMODULES_GUIDE.md) - Working with submodules

### Common Patterns

**YAML Workflow Specifications**:
- Each repo has `design_specs/control_flows.yml`
- Defines phase → step → unit workflow
- See control-flow docs for specification format

**Universal Libraries**:
- Shared across all repos via control-flow
- See LIBRARY_ARCHITECTURE.md for complete catalog
- Import via: `from phases.libraries.* import *`

**Documentation Philosophy**:
- **Main repo**: Strategic architecture, integration patterns
- **Submodules**: Implementation details, API references, progress tracking

---

## How to Use This Index

### For New Developers

**Start Here**:
1. [ARCHITECTURE.md](architecture/ARCHITECTURE.md) - Understand multi-repo system
2. [CONTROL_FLOW_INTEGRATION.md](project/CONTROL_FLOW_INTEGRATION.md) - Learn workflow orchestration
3. Choose your component → Read its docs from this index

### For Implementation Work

**Config-Manager Development**:
→ `external/config-manager/docs/CONFIG_MANAGER_IMPLEMENTATION.md`

**Deploy-Manager Development**:
→ `external/deploy-manager/docs/IMPLEMENTATION_PROGRESS.md` (current status)  
→ `external/deploy-manager/docs/DEPLOY_MANAGER_PROPOSAL.md` (architecture)

**Control-Flow Development**:
→ `external/control-flow/docs/DOCUMENTATION_INDEX.md` (start here)  
→ `external/control-flow/docs/LIBRARY_DEVELOPMENT_GUIDE.md` (creating libraries)

### For Architecture Understanding

**Strategic Overview**:
- Main repo: [ARCHITECTURE.md](architecture/ARCHITECTURE.md)
- Control-flow role: [CONTROL_FLOW_INTEGRATION.md](project/CONTROL_FLOW_INTEGRATION.md)

**Implementation Details**:
- Config-manager: Submodule docs (this index)
- Deploy-manager: Submodule docs (this index)

### For Historical Context

**Archived Designs**:
→ [docs/archive/historical/](archive/historical/) - Original proposals before implementation

---

## Maintenance

**Updating This Index**:
- When submodule docs change significantly
- When new submodules are added
- When documentation is reorganized
- Every quarter (minimum)

**Last Review**: October 16, 2025  
**Next Review**: January 2026

---

**Quick Links**:
- [Main Docs Index](README.md)
- [Architecture Overview](architecture/ARCHITECTURE.md)
- [Control-Flow Integration](project/CONTROL_FLOW_INTEGRATION.md)
- [Historical Archive](archive/historical/)
