# OpenProject Docker Compose - Documentation

This directory contains all design documents, architectural specifications, guides, and project documentation for the OpenProject Docker Compose system.

## 📁 Directory Structure

### 🏗️ **architecture/**
System architecture and design specifications
- `ARCHITECTURE.md` - Comprehensive system architecture and component interactions

### 🎨 **design/**  
Design specifications and workflow documentation
- `CONFIG_VARIABLE_FLOW.md` - Configuration variable flow and management design

### 📚 **guides/**
User and developer guides  
- `SUBMODULES_GUIDE.md` - Guide for working with Git submodules
- `MANAGER_FOLDERS.md` - Guide to manager component organization

### 🔄 **migration/**
Migration plans and rebuild documentation
- `MIGRATION_PLAN.md` - Comprehensive migration strategy and implementation plan
- `PYTHON_REBUILD.md` - Python rebuild phases and progress tracking

### 📋 **project/**
Project overview and summary documentation
- `PROJECT_OVERVIEW.md` - Complete project overview and component descriptions  
- `PROJECT_STRUCTURE_MASTER.md` - Master reference for project structure
- `MULTI_REPO_SUMMARY.md` - Multi-repository structure and relationships
- `CONTROL_FLOW_INTEGRATION.md` - How control-flow engine integrates across all repos
- `BRANCH_RESTRUCTURE_COMPLETE.md` - Branch restructuring completion summary
- `DEPENDENCY_ANALYSIS.md` - Cross-repository dependency analysis
- `COMPLETE_PROJECT_CONTEXT.md` - Complete system context and architecture

### 📦 **Submodule Documentation**
Implementation details in external repositories
- `SUBMODULE_DOCUMENTATION.md` - **Complete index of all submodule documentation**
- **Config-Manager**: `external/config-manager/docs/CONFIG_MANAGER_IMPLEMENTATION.md`
- **Deploy-Manager**: `external/deploy-manager/docs/`
- **Control-Flow**: `external/control-flow/docs/DOCUMENTATION_INDEX.md`

### 📜 **archive/**
Historical documentation preserved for context
- `historical/` - Archived design proposals superseded by implementation
- See `archive/historical/README.md` for details on archived documents

## 🎯 **Document Categories**

### **For Developers**
- Start with `project/PROJECT_OVERVIEW.md` for system understanding
- Review `project/CONTROL_FLOW_INTEGRATION.md` for workflow orchestration
- Study `architecture/ARCHITECTURE.md` for technical details
- Check `guides/` for development workflows
- Reference `migration/` for current development status

### **For System Administrators**
- Begin with `project/PROJECT_OVERVIEW.md` for deployment context
- Review `guides/SUBMODULES_GUIDE.md` for repository management
- Check `architecture/` for system design understanding

### **For Contributors**
- Read `project/MULTI_REPO_SUMMARY.md` for repository structure
- Study `migration/MIGRATION_PLAN.md` for development roadmap
- Review `design/` for workflow specifications

## 🔗 **Cross-References**

Many documents reference each other. Key relationships:
- `PROJECT_OVERVIEW.md` ↔ `ARCHITECTURE.md` (overview ↔ details)
- `CONTROL_FLOW_INTEGRATION.md` ↔ `external/control-flow/docs/` (integration ↔ engine details)
- `MIGRATION_PLAN.md` ↔ `PYTHON_REBUILD.md` (planning ↔ execution)
- `MULTI_REPO_SUMMARY.md` ↔ `SUBMODULES_GUIDE.md` (structure ↔ workflow)
- `ARCHITECTURE.md` ↔ `SUBMODULE_DOCUMENTATION.md` (strategy ↔ implementation)

### **Documentation Philosophy**

**Main Repository Docs** (this directory):
- ✅ Strategic architecture and integration patterns
- ✅ Cross-repository coordination and planning
- ✅ High-level guides and project overview

**Submodule Docs** (external/*/docs/):
- ✅ Implementation details and API references
- ✅ Component-specific development guides
- ✅ Progress tracking and completion reports

**See**: `SUBMODULE_DOCUMENTATION.md` for complete submodule documentation index

## 📝 **Maintenance**

This documentation is actively maintained and updated as the system evolves. When making changes:

1. **Update cross-references** if moving or renaming documents
2. **Maintain consistency** across related documents
3. **Update this README** when adding new document categories
4. **Keep architecture and overview docs in sync** with actual implementation

## 🚀 **Getting Started**

**New to the project?** Start here:
1. `project/PROJECT_OVERVIEW.md` - Understand what this system does
2. `project/CONTROL_FLOW_INTEGRATION.md` - Learn how workflows are orchestrated
3. `architecture/ARCHITECTURE.md` - Deep dive into technical architecture
4. `SUBMODULE_DOCUMENTATION.md` - **Navigate to implementation details**
5. `guides/SUBMODULES_GUIDE.md` - Set up your development environment
6. `migration/PYTHON_REBUILD.md` - See current development status

The documentation is organized to support both high-level understanding and deep technical implementation details. 

**Implementation Details**:
- For control-flow engine: `external/control-flow/docs/DOCUMENTATION_INDEX.md`
- For config-manager: `external/config-manager/docs/CONFIG_MANAGER_IMPLEMENTATION.md`
- For deploy-manager: `external/deploy-manager/docs/`
- **Complete index**: `SUBMODULE_DOCUMENTATION.md`