# OpenProject Orchestrator - User Guide

> **Version 2.0.0** - Interactive TUI for OpenProject Deployment

A sophisticated command-line orchestrator that provides an interactive terminal interface for deploying and managing OpenProject with Docker Compose.

## ✨ Features

- **🚀 Quick Deploy** - One-command deployment from zero to running OpenProject
- **⚙️ Interactive Configuration** - Guided 5-phase configuration workflow
- **📦 Deployment Management** - Full lifecycle control with progress tracking
- **📊 Enhanced Status Dashboard** - Real-time system monitoring
- **🔄 Dual-Mode Support** - Works in development and production environments

## 🚀 Quick Start

### Installation

The orchestrator is included in the OpenProject docker-compose repository:

```bash
# Clone the repository with submodules
git clone --recursive https://github.com/JustinCBates/openproject-docker-compose.git
cd openproject-docker-compose

# Install the orchestrator
pip install -e .
```

### Launch

```bash
# Start the interactive TUI
openproject deploy

# Enable debug mode for verbose logging
openproject deploy --debug
```

## 📖 Usage

### Quick Deploy (Recommended)

The fastest way to get OpenProject running:

1. Run `openproject deploy`
2. Select `1` for Quick Deploy
3. Follow the prompts:
   - Provide domain and email
   - Select deployment mode
   - Wait for verification

### Individual Workflows

**Configure OpenProject**:
- Select option `2` from the main menu
- Complete the 5-phase configuration

**Deploy Services**:
- Select option `3` from the main menu  
- Choose development or production mode

**View Status**:
- Select option `8` to see detailed system status

## 📁 File Structure

```
workspace/
├── config.yaml              # Generated configuration
├── .env                     # Environment variables
├── outputs/                 # Generated deployment files
└── logs/                    # Orchestrator logs
    └── orchestrator_*.log   # Timestamped log files
```

## 🔧 Configuration

Configuration is automatically managed through the interactive workflows. Files are saved to `./workspace/`:

- `config.yaml` - Main configuration
- `.env` - Environment variables for Docker Compose

## 📊 Status Dashboard

The status dashboard (option `8`) shows:

- **Configuration Status**: Whether system is configured
- **Deployment Status**: Service count and deployment time
- **Configuration Details**: Domain, email, SSL/SMTP settings
- **Quick Actions**: Context-aware suggestions

## 🐛 Troubleshooting

### Enable Debug Mode

```bash
openproject deploy --debug
```

### View Logs

```bash
tail -f ./workspace/logs/orchestrator_*.log
```

### Common Issues

**Submodule not initialized**:
```bash
git submodule update --init --recursive
```

**Permission denied**:
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

## 🗺️ Roadmap

**Current** (v2.0.0):
- ✅ Core workflows
- ✅ Quick Deploy
- ✅ Enhanced status dashboard

**Future** (v2.1+):
- ⏳ Backup/Restore
- ⏳ Health monitoring
- ⏳ Log viewing
- ⏳ File server integration
- ⏳ Gitea integration

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/JustinCBates/openproject-docker-compose/issues)
- **Documentation**: See `/docs` directory

## 📄 License

MIT License - see LICENSE file for details.

---

**Part of the OpenProject deployment suite**
