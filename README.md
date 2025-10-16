# OpenProject - Complete Project Management Solution

OpenProject is an open-source project management software with a wide set of features and plugins.

## Quick Installation

**System Requirements:**
- Docker & Docker Compose
- 4GB+ RAM recommended
- 10GB+ available disk space

### 1. Download OpenProject

```bash
# Download the latest release
wget https://github.com/JustinCBates/openproject-docker-compose/releases/latest/download/openproject-deploy.tar.gz

# Extract and enter directory
tar -xzf openproject-deploy.tar.gz
cd openproject-deploy
```

### 2. Configure Environment

```bash
# Copy the example configuration
cp .env.example .env

# Edit configuration (optional - defaults work for most setups)
nano .env
```

### 3. Create Data Directory

```bash
# Create data directory with correct permissions
sudo mkdir -p /var/openproject/assets
sudo chown 1000:1000 -R /var/openproject/assets
```

### 4. Start OpenProject

```bash
# Start all services
OPENPROJECT_HTTPS=false docker compose up -d --build --pull always
```

OpenProject will be available at **http://localhost:8080**

**Default credentials:**
- Username: `admin`
- Password: `admin`

> **Security Note:** Change the default admin password immediately after first login.

## Configuration

### Environment Variables

Common configuration options in `.env`:

```bash
# Port configuration
PORT=8080                          # Default: 8080
# PORT=127.0.0.1:8080              # Bind to localhost only

# HTTPS configuration  
OPENPROJECT_HTTPS=false            # Default: true (requires reverse proxy)

# Docker image version
TAG=16                             # OpenProject version

# Database settings
POSTGRES_PASSWORD=p4ssw0rd          # Database password
POSTGRES_DB=openproject            # Database name

# Data persistence
OPDATA=/var/openproject/assets     # Data storage location
```

### HTTPS Setup

OpenProject defaults to HTTPS mode but requires a reverse proxy for SSL termination:

```bash
# For development/testing - disable HTTPS
OPENPROJECT_HTTPS=false

# For production - set up reverse proxy (Apache/Nginx) and enable HTTPS
OPENPROJECT_HTTPS=true
```

### Custom Port

```bash
# Change port
PORT=4000

# Bind to specific interface
PORT=127.0.0.1:8080
```

## Management Commands

### View Logs
```bash
docker compose logs -f
docker compose logs -f web      # Web container only
```

### Stop/Start Services
```bash
docker compose stop             # Stop services
docker compose start            # Start services
docker compose restart          # Restart services
```

### Backup Data
```bash
# Create backup
docker compose -f docker-compose.yml -f docker-compose.control.yml run backup

# Backup files are stored in ./backups/
```

### Upgrade OpenProject
```bash
# Pull latest changes
git pull origin production

# Backup before upgrade
docker compose -f docker-compose.yml -f docker-compose.control.yml run backup

# Run upgrade
docker compose -f docker-compose.yml -f docker-compose.control.yml run upgrade

# Restart with latest images
docker compose up -d --build --pull always
```

## Troubleshooting

### Common Issues

**Cannot access OpenProject (ERR_SSL_PROTOCOL_ERROR)**
- Set `OPENPROJECT_HTTPS=false` for local development
- For production, configure a reverse proxy for SSL termination

**Permission denied errors**
- Ensure data directory has correct permissions: `sudo chown 1000:1000 -R /var/openproject/assets`

**Port already in use**
- Change the port in `.env`: `PORT=8081`
- Or stop the conflicting service

**Pull access denied for proxy image**
- This is a warning and can be ignored
- Use `docker compose pull --ignore-buildable` to suppress

### Getting Help

**View container status:**
```bash
docker compose ps
```

**Check container logs:**
```bash
docker compose logs web
docker compose logs db
```

**Reset to clean state:**
```bash
# Stop all containers
docker compose down

# Remove data (WARNING: This deletes all data!)
docker volume rm compose_opdata compose_pgdata

# Start fresh
docker compose up -d
```

## Uninstall

### Stop Services Only
```bash
docker compose stop
```

### Remove Containers (Keep Data)
```bash
docker compose down
```

### Complete Removal (Including Data)
```bash
# Stop and remove containers
docker compose down

# Remove data volumes (WARNING: This deletes all data!)
docker volume rm compose_opdata compose_pgdata

# Remove downloaded files
cd .. && rm -rf openproject-deploy
```

## Support

- **Documentation:** https://docs.openproject.org/
- **Community:** https://community.openproject.org/
- **Issues:** https://github.com/JustinCBates/openproject-docker-compose/issues

## License

OpenProject is licensed under the GNU General Public License version 3.