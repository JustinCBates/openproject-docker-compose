# Code Quality Audit - OpenProject Main Repo

**Date**: October 20, 2025  
**Branch**: refactor/quality-hardening  
**Scope**: Main openproject orchestrator (`src/openproject_orchestrator`)

---

## Summary

Performed quality hardening on the main openproject orchestrator repository to align with best practices established in the external submodules (config-manager, deploy-manager, control-flow).

**Key Improvements:**
- ✅ Removed runtime `sys.path.insert` hacks
- ✅ Fixed bare `except:` clauses (E722)
- ✅ Applied Black code formatting (line-length 88)
- ✅ Added pre-commit hooks for automated enforcement
- ✅ Established consistent code quality baseline

---

## Detailed Changes

### 1. Path Hygiene (sys.path.insert removal)

**Files Modified:**
- `src/openproject_orchestrator/coordinators/deploy_coordinator.py`
- `src/openproject_orchestrator/coordinators/config_coordinator.py`

**Issue**: Both coordinators used runtime `sys.path.insert()` to load external submodules in development mode.

**Fix**: Removed path manipulation; documented proper approach:
- **Development**: Install submodules in editable mode (`pip install -e external/deploy-manager/`)
- **Production**: Use installed packages (`pip install openproject-deploy-manager`)

**Rationale**: Runtime path manipulation is fragile and violates Python packaging best practices. Proper editable installs ensure imports work consistently across environments.

### 2. Exception Handling

**Files Modified:**
- `src/openproject_orchestrator/tui_controller.py` (2 instances)

**Issue**: Bare `except:` clauses on lines 521 and 610 (E722 flake8 violation).

**Fix**: Changed to `except (ValueError, TypeError, AttributeError):` with explanatory comments.

**Context**: Both instances were datetime parsing fallbacks. Specific exception types improve debugging and prevent masking unexpected errors.

### 3. Code Formatting

**Black Applied to:**
- `src/openproject_orchestrator/` (all modules)
- `tests/` (all test files)

**Stats:**
- 9 files reformatted
- 4 files already compliant
- Line length: 88 characters (Black default)

**Result**: Consistent, PEP 8-compliant formatting across the codebase.

### 4. Pre-commit Hooks

**Configuration**: `.pre-commit-config.yaml`

**Hooks Installed:**
1. **Black** (v25.9.0): Auto-format Python code
2. **Flake8** (v7.1.1): Lint with relaxed rules initially (F401 and others ignored for incremental enforcement)
3. **pyupgrade** (v3.19.0): Modernize Python syntax (--py38-plus)
4. **pre-commit-hooks** (v4.6.0): EOF/trailing whitespace, YAML/TOML checks, merge conflict detection

**Exclusions**: `external/`, `testing/`, `venv/`, `.venv/`, `*.egg-info/`

**Scope**: Hooks run only on `src/` and `tests/` to avoid touching submodule code.

---

## Anti-Patterns Scan Results

### sys.path.insert
- **Found**: 2 instances (both in coordinators)
- **Fixed**: ✅ All removed

### Bare except:
- **Found**: 2 instances (both in tui_controller.py)
- **Fixed**: ✅ All replaced with specific exception types

### print() statements
- **Found**: 50+ instances (all `console.print()` from Rich library)
- **Status**: ✅ Appropriate for CLI/TUI code; no changes needed

### Missing logging
- **Status**: ✅ Coordinators use Rich Console for user-facing output; appropriate for TUI

---

## Testing

**Baseline**: No automated test suite detected in main repo tests directory beyond placeholder files.

**Pre-commit Validation**:
```bash
$ pre-commit run --all-files
black (python)...........................................................Passed
flake8 (src - relaxed)...................................................Passed
pyupgrade................................................................Passed
fix end of files.........................................................Passed
trailing whitespace......................................................Passed
check yaml...............................................................Passed
check toml...............................................................Passed
check for merge conflicts................................................Passed
```

**Manual Verification**:
- Coordinators import cleanly (pending editable installs of submodules)
- Black formatting consistent across all files
- No E722 (bare except) violations remain

---

## Metrics

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| sys.path.insert | 2 | 0 | -100% |
| Bare except: | 2 | 0 | -100% |
| Black-formatted files | 4 | 13 | +225% |
| Pre-commit hooks | 0 | 8 | +∞ |

---

## Follow-up Tasks

### Short-term (Next PR)
1. **Tighten Flake8 Rules**: Enable F401 (unused imports) for `src/` and `tests/`; remove unused imports.
2. **Add Flake8 E402**: Enforce import order (imports at top of file).
3. **CI Integration**: Add pre-commit to GitHub Actions workflow.

### Medium-term
1. **Test Coverage**: Add unit tests for coordinators (currently minimal).
2. **Type Hints**: Add comprehensive type annotations for better IDE support.
3. **Logging**: Consider structured logging for coordinator operations (currently using Rich console).

### Long-term
1. **Packaging**: Publish `openproject-orchestrator` as installable package.
2. **Documentation**: Generate API docs from docstrings.

---

## Developer Setup

After pulling this branch, developers should:

1. **Install pre-commit**:
   ```bash
   pip install pre-commit
   cd /opt/openproject
   pre-commit install
   ```

2. **Install submodules in editable mode** (for development):
   ```bash
   pip install -e external/config-manager/
   pip install -e external/deploy-manager/
   ```

3. **Run hooks manually** (optional):
   ```bash
   pre-commit run --all-files
   ```

4. **Format code** (auto on commit, or manual):
   ```bash
   black src tests
   ```

---

## Conclusion

The main openproject repository now follows the same quality standards as its external submodules. Runtime path hacks eliminated, code consistently formatted, and automated enforcement via pre-commit ensures ongoing compliance.

**Next Steps**: Merge to `develop`, delete refactor branch, and begin incremental Flake8 tightening (F401, E402).
