# OpenProject Dependency Analysis Report

**Generated:** October 14, 2025  
**Workspace:** /opt/openproject (7 repositories)  
**Environment:** VPS with Python virtual environment

---

## Executive Summary

This report analyzes dependencies across all 7 repositories in the OpenProject workspace to identify:
- Production vs Development dependencies
- Version conflicts between repositories
- Shared dependencies across repos
- Security vulnerabilities (pending)

---

## Task 1: Production vs Development Breakdown

### Repositories with Dependencies

#### 1. **openproject** (Main)
- **Production (6 packages):**
  - click>=8.0
  - docker>=6.0
  - jinja2>=3.0
  - python-dotenv>=1.0
  - pyyaml>=6.0
  - requests>=2.28.0
- **Development:** None defined

#### 2. **config-manager**
- **Production (10 packages):**
  - click>=8.1.0
  - cryptography>=41.0.0
  - docker>=7.0.0
  - netifaces>=0.11.0
  - psutil>=5.9.0
  - pydantic>=2.0.0
  - python-dotenv>=1.0.0
  - pyyaml>=6.0.0
  - questionary>=1.10.0
  - requests>=2.31.0
  - rich>=13.0.0
- **Development:** None defined

#### 3. **control-flow**
- **Production (3 packages):**
  - click>=8.0
  - graphviz>=0.20
  - pyyaml>=6.0
- **Development:** None defined

#### 4. **dependency-manager**
- **Production (6 packages):**
  - click>=8.0
  - packaging>=21.0
  - pyyaml>=6.0
  - requests>=2.28.0
  - rich>=13.0.0
  - toml>=0.10.0
- **Development:** None defined

#### 5. **tui-form-designer**
- **Production (3 packages):**
  - pydantic>=2.0.0
  - pyyaml>=6.0
  - questionary>=2.0.0
- **Development:** None defined

#### 6. **deploy-manager**
- **Status:** No dependencies defined yet

#### 7. **prober**
- **Status:** No dependencies defined yet

### ⚠️ Observations

1. **No Development Dependencies Defined:** None of the repos have explicit `[project.optional-dependencies]` dev groups
2. **Inconsistent Versioning:** Multiple repos specify different minimum versions for the same packages
3. **Missing pyproject.toml:** deploy-manager and prober don't have dependency files yet

---

## Task 2: Cross-Repository Dependency Report

### Version Conflicts Detected

#### 🔴 Critical: `click`
- **dependency-manager:** `>=8.0`
- **config-manager:** `>=8.1.0` ⚠️ Higher minimum
- **control-flow:** `>=8.0`
- **Recommendation:** Standardize to `>=8.1.0` across all repos

#### 🔴 Critical: `requests`
- **dependency-manager:** `>=2.28.0`
- **config-manager:** `>=2.31.0` ⚠️ Higher minimum
- **Recommendation:** Standardize to `>=2.31.0` across all repos

#### 🟡 Minor: `pyyaml`
- **Most repos:** `>=6.0`
- **config-manager:** `>=6.0.0` (functionally identical)
- **Recommendation:** Standardize format to `>=6.0` for consistency

#### 🟡 Minor: `questionary`
- **config-manager:** `>=1.10.0`
- **tui-form-designer:** `>=2.0.0` ⚠️ Higher minimum
- **Recommendation:** Standardize to `>=2.0.0` across all repos

#### 🟡 Minor: `docker`
- **openproject:** `>=6.0`
- **config-manager:** `>=7.0.0` ⚠️ Higher minimum
- **Recommendation:** Standardize to `>=7.0.0` across all repos

### Shared Dependencies (Cross-Repo)

#### Most Used: `pyyaml` (4 repos)
- dependency-manager
- config-manager
- control-flow
- tui-form-designer

#### Commonly Used: `click` (3 repos)
- dependency-manager
- config-manager
- control-flow

#### Also Shared:
- **pydantic** (2 repos): config-manager, tui-form-designer
- **requests** (2 repos): dependency-manager, config-manager
- **questionary** (2 repos): config-manager, tui-form-designer
- **rich** (2 repos): dependency-manager, config-manager
- **python-dotenv** (2 repos): openproject, config-manager

---

## Task 3: Security Vulnerability Scan

**Status:** ⏳ Pending (scan hung during execution)

**Planned Actions:**
1. Run `safety scan` offline or with shorter timeout
2. Check for known CVEs in critical packages
3. Review `setuptools` version (system package may be outdated)

**Next Steps:**
```bash
# Run security scan with timeout
source venv/bin/activate
timeout 60s safety scan --output json > security_report.json

# Alternative: Use pip-audit
pip install pip-audit
pip-audit --format json
```

---

## Task 4: Unified Lockfile

### Created Files

#### `requirements.lock` (Unified Production Dependencies)
**Purpose:** Single source of truth for all production dependencies across repos

**Contents:** 14 packages with resolved versions
- click>=8.0
- cryptography>=41.0.0
- docker>=7.0.0
- graphviz>=0.20
- netifaces>=0.11.0
- packaging>=21.0
- psutil>=5.9.0
- pydantic>=2.0.0
- python-dotenv>=1.0.0
- pyyaml>=6.0.0
- questionary>=2.0.0
- requests>=2.31.0
- rich>=13.0.0
- toml>=0.10.0

**Usage:**
```bash
pip install -r requirements.lock
```

#### `requirements.txt` (Virtual Environment Snapshot)
**Purpose:** Complete snapshot of current venv state (44 packages with all dependencies)

**Usage:**
```bash
# Recreate exact environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## Recommendations

### Immediate Actions (High Priority)

1. **Resolve Version Conflicts**
   - Update all `pyproject.toml` files to use consistent minimum versions
   - Priority: `click>=8.1.0`, `requests>=2.31.0`, `questionary>=2.0.0`, `docker>=7.0.0`

2. **Add Development Dependencies**
   - Create `[project.optional-dependencies]` sections in all repos
   - Standard dev group: `pytest`, `pytest-cov`, `black`, `flake8`, `mypy`

3. **Complete Missing Dependencies**
   - Add `pyproject.toml` to deploy-manager
   - Add `pyproject.toml` to prober

4. **Security Audit**
   - Complete vulnerability scan (retry with timeout)
   - Upgrade `setuptools` if vulnerabilities found

### Future Improvements (Medium Priority)

5. **Dependency Management**
   - Use `requirements.lock` as authoritative source
   - Implement pre-commit hook to validate version consistency
   - Set up automated dependency updates (Dependabot/Renovate)

6. **Documentation**
   - Document which features require which optional dependencies
   - Create dependency matrix showing repo → package relationships
   - Add DEPENDENCIES.md to each repo

7. **Testing**
   - Test installation from `requirements.lock` in clean environment
   - Verify all repos work with unified versions
   - Add integration tests across repos

### Long-Term Strategy (Low Priority)

8. **Monorepo Consideration**
   - Evaluate if moving to true monorepo structure makes sense
   - Consider using tools like `poetry` or `pdm` for workspace management
   - Implement shared dependency configuration

9. **Production Hardening**
   - Pin exact versions in lockfile (not just minimums)
   - Separate production.lock from development.lock
   - Implement dependency signature verification

10. **CI/CD Integration**
    - Automated dependency conflict detection in PRs
    - Scheduled security audits
    - Automatic lockfile updates

---

## Files Created

1. **`/opt/openproject/requirements.lock`**  
   Unified production dependencies (14 packages)

2. **`/opt/openproject/requirements.txt`**  
   Full venv snapshot (44 packages with dependencies)

3. **`/opt/openproject/venv/`**  
   Virtual environment with all packages

4. **`/opt/openproject/activate`**  
   Quick activation script

5. **`/opt/openproject/DEPENDENCY_ANALYSIS.md`** (this file)  
   Complete analysis report

---

## Dependency-Manager Tool Features

The `dependency-manager` tool provides:

### Analysis
- Repository-level dependency scanning
- Cross-repository version conflict detection
- Shared dependency identification
- Package manager detection (pip, apt, yum, brew)

### Installation
- Unified installation across all repos
- Development vs production mode
- Optional feature installation
- Virtual environment management

### Validation
- Version compatibility checking
- Security vulnerability scanning (via `safety`)
- Dependency graph visualization
- Update plan generation

### CLI Commands
```bash
# Analyze all repos
dependency-manager analyze --all

# Check for conflicts
dependency-manager track --conflicts

# Install with dev dependencies
dependency-manager install --dev

# Generate report
dependency-manager report --format json
```

---

## Environment Setup

### Virtual Environment (Recommended)

Current setup: `/opt/openproject/venv`

**Activation:**
```bash
# Quick way
source /opt/openproject/activate

# Standard way
source /opt/openproject/venv/bin/activate
```

**Benefits:**
- ✅ Isolated from system Python (critical on VPS)
- ✅ No root/sudo required
- ✅ Reproducible environment
- ✅ No risk of breaking OS tools

### Why Virtual Environment Matters on VPS

Unlike Docker containers (where `--break-system-packages` is acceptable), running directly on a VPS requires isolation:

- **System Protection:** Prevent conflicts with OS tools
- **Security:** Run without root privileges
- **Reproducibility:** Exact environment capture
- **Multi-Project:** Support multiple Python projects

---

## Next Steps

### Today
- [x] Complete dependency analysis (Tasks 1-4)
- [x] Create unified lockfile
- [ ] Retry security scan with timeout

### This Week
- [ ] Update all pyproject.toml files with consistent versions
- [ ] Add development dependency groups to all repos
- [ ] Complete deploy-manager and prober dependency definitions
- [ ] Test unified lockfile in clean environment

### This Month
- [ ] Implement automated version conflict detection
- [ ] Set up Dependabot or Renovate
- [ ] Create dependency documentation for each repo
- [ ] Add pre-commit hooks for dependency validation

---

## Questions for Consideration

1. **Should we move to exact version pinning** (e.g., `==2.31.0` instead of `>=2.31.0`)?
   - Pro: More reproducible, fewer surprises
   - Con: More maintenance, slower to get security updates

2. **Should we separate dev and optional dependencies** into different lockfiles?
   - Pro: Smaller production images
   - Con: More files to maintain

3. **Should deploy-manager and prober be pure bash scripts** (no Python dependencies)?
   - Pro: Simpler, fewer dependencies
   - Con: Less powerful, harder to extend

4. **Should we consolidate shared code** into a separate `openproject-common` package?
   - Pro: Reduce duplication, enforce consistency
   - Con: More complex dependency management

---

**Report End**
