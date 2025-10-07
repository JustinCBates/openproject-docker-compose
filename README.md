# OpenProject installation with Docker Compose

This repository contains the installation method for OpenProject using Docker Compose.


> [!NOTE]
> Looking for the Kubernetes installation method?
> Please use the [OpenProject helm chart](https://charts.openproject.org) to install OpenProject on kubernetes.

## Prerequisites

### Supported Operating Systems

This deployment framework supports the following Linux distributions and families:

#### Debian Family
- **Ubuntu** (18.04 LTS, 20.04 LTS, 22.04 LTS, 24.04 LTS)
- **Debian** (10, 11, 12)
- **Linux Mint** (20.x, 21.x, 22.x)
- **Raspbian** (Buster, Bullseye, Bookworm)

**Update package repositories and install Git:**
```shell
sudo apt update
sudo apt upgrade -y
sudo apt install git curl -y
```

#### Red Hat Family
- **Red Hat Enterprise Linux (RHEL)** (8, 9)
- **CentOS** (7, 8, Stream 8, Stream 9)
- **Fedora** (38, 39, 40)
- **Rocky Linux** (8, 9)
- **AlmaLinux** (8, 9)

**Update package repositories and install Git:**
```shell
# For modern systems (Fedora, RHEL 8+, Rocky, AlmaLinux)
sudo dnf update -y
sudo dnf install git curl -y

# For older systems (CentOS 7, RHEL 7)
sudo yum update -y
sudo yum install git curl -y
```

#### SUSE Family
- **openSUSE Leap** (15.4, 15.5, 15.6)
- **openSUSE Tumbleweed** (Rolling release)
- **SUSE Linux Enterprise Server (SLES)** (15 SP4, 15 SP5)

**Update package repositories and install Git:**
```shell
sudo zypper refresh
sudo zypper update -y
sudo zypper install git curl -y
```

#### Arch Family
- **Arch Linux** (Rolling release)
- **Manjaro** (Rolling release)
- **EndeavourOS** (Rolling release)
- **ArcoLinux** (Rolling release)

**Update package repositories and install Git:**
```shell
sudo pacman -Syu --noconfirm
sudo pacman -S git curl --noconfirm
```

#### Slackware Family
- **Slackware** (15.0+)
- **Slackware64** (15.0+)

**Update package repositories and install Git:**
```shell
# Update package database (if using slackpkg)
sudo slackpkg update

# Install Git and curl
sudo slackpkg install git curl

# Alternative: Build from SlackBuilds.org if packages not available
# Git and curl are often included in full Slackware installations
```

### System Requirements

**Minimum Requirements:**
- 4 GB RAM
- 20 GB available disk space
- 64-bit processor architecture
- Root or sudo access

**Recommended for Production:**
- 8 GB+ RAM
- 50 GB+ available disk space
- SSD storage for better performance
- Dedicated server or VPS

### Network Requirements

- Internet connectivity for downloading Docker images and packages
- Ports 80 and 443 available for HTTP/HTTPS (production)
- Port 8080 available for development/staging deployments

## Quick start

### Option 1: Interactive Deployment Script (Recommended)

The easiest way to deploy OpenProject is using our interactive deployment script that automatically detects your OS, installs Docker, and configures the environment.

#### Interactive Deployment Steps

1. **Clone the repository:**
   ```shell
   # Choose your installation directory
   OPENPROJECT_PATH="/opt/openproject"  # or your preferred location
   sudo mkdir -p "$OPENPROJECT_PATH"
   git clone https://github.com/JustinCBates/openproject-docker-compose.git --branch=feature/stepwise-rebuild "$OPENPROJECT_PATH"
   cd "$OPENPROJECT_PATH"
   ```

2. **Run the interactive deployment script:**
   ```shell
   sudo ./scripts/installation_scripts/deploy_interactive.sh
   ```

   This script will:
   - Auto-detect your Linux distribution and OS family
   - Prompt for environment type (development/staging/production)
   - Configure domain settings and networking
   - Set up Git user configuration
   - Install and configure Docker automatically
   - Generate optimized configuration files

3. **Execute the deployment:**
   ```shell
   sudo ./scripts/installation_scripts/deploy.sh
   ```

4. **Start OpenProject:**
   ```shell
   # For development/staging
   OPENPROJECT_HTTPS=false docker compose up -d --build --pull always
   
   # For production (with HTTPS)
   docker compose up -d --build --pull always
   ```

After a few minutes, OpenProject will be available at your configured domain or `http://localhost:8080`.
Default credentials: **Username:** `admin` **Password:** `admin`

### Option 2: Manual Setup

If you prefer manual configuration or need custom settings, follow these steps:

#### Install Docker (Manual)

After completing the prerequisites above, install Docker manually for your distribution:

**All Distributions (Universal Docker Install):**
```shell
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

**Distribution-Specific Docker Installation:**

**Debian/Ubuntu:**
```shell
sudo apt install docker.io docker-compose -y
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

**SUSE:**
```shell
sudo zypper install docker docker-compose -y
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

**Arch:**
```shell
sudo pacman -S docker docker-compose --noconfirm
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

#### Manual Repository Setup

First, choose a directory where you want to install OpenProject and clone this repository:

```shell
# Set your preferred installation directory
OPENPROJECT_PATH="/opt/openproject"  # or your preferred location
sudo mkdir -p "$OPENPROJECT_PATH"

# Clone the enhanced version of the repository
git clone https://github.com/JustinCBates/openproject-docker-compose.git --branch=feature/stepwise-rebuild "$OPENPROJECT_PATH"

# Change to the OpenProject directory
cd "$OPENPROJECT_PATH"
```

#### Manual Configuration

Copy the example `.env` file and edit any values you want to change:

```shell
cp .env.example .env
vim .env
```

If you are using the default value of OPDATA that is used in the ```.env.example``` you need to make sure that the folder exist, and you have the right permissions:

```shell
sudo mkdir -p /var/openproject/assets
sudo chown 1000:1000 -R /var/openproject/assets
```

Next you start up the containers in the background while making sure to pull the latest versions of all used images.

```shell
OPENPROJECT_HTTPS=false docker compose up -d --build --pull always
```

After a while, OpenProject should be up and running on `http://localhost:8080`. The default username and password is login: `admin`, and password: `admin`.
The `OPENPROJECT_HTTPS=false` environment variable explicitly disables HTTPS mode for the first startup. Without this, OpenProject assumes it's running behind HTTPS in production by default.
We do strongly recommend you use OpenProject behind a TLS terminated proxy for production purposes and remove this flag before actually starting to use it.

## Enhanced Deployment Features

This repository includes an enhanced deployment framework with the following features:

### Automated Installation Scripts

- **OS Detection**: Automatically detects your Linux distribution and family
- **Docker Installation**: Smart Docker detection and installation for all major Linux distributions
- **Version Checking**: Skips unnecessary reinstallation if Docker is already current
- **Multi-Distribution Support**: 
  - Debian family (Ubuntu, Debian, Linux Mint, Raspbian)
  - Red Hat family (RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux)
  - SUSE family (openSUSE, SLES)
  - Arch family (Arch, Manjaro, EndeavourOS)
  - Slackware family

### Interactive Configuration

- **Environment Selection**: Choose between development, staging, or production configurations
- **Domain Configuration**: Set up custom domains and subdomains
- **Git Integration**: Configure Git user settings for deployment tracking
- **HTTPS Setup**: Automatic HTTPS configuration for production environments

### Deployment Scripts Location

All deployment scripts are organized under:
```
scripts/installation_scripts/
├── deploy_interactive.sh    # Interactive configuration
├── deploy.sh               # Automated deployment orchestrator
└── installation_utilities/ # OS-specific installation scripts
```

### Configuration Management

The framework uses a configuration file (`deploy_interactive.cfg`) to store all deployment settings, ensuring consistent deployments and easy script reuse.

### Customization

The `docker-compose.yml` file present in the repository can be adjusted to your convenience. But note that with each pull, it will be overwritten.
Best practice is to use the file `docker-compose.override.yml` for that case.
For instance you could mount specific configuration files, override environment variables, or switch off services you don't need.

Please refer to the official [Docker Compose documentation](https://docs.docker.com/compose/extends/) for more details.

### Troubleshooting

**pull access denied for openproject/proxy, repository does not exist or may require 'docker login': denied: requested access to the resource is denied**

If you encounter this after `docker compose up` this is merely a warning which can be ignored.

If this happens during `docker compose pull` this is simply a warning as well.
But it will result in the command's exit code to be a failure even though all images are pulled.
To prevent this you can add the `--ignore-buildable` option, running `docker compose pull  --ignore-buildable`.

### HTTPS/SSL

By default OpenProject starts with the HTTPS option **enabled**, but it **does not** handle SSL termination itself. This
is usually done separately via a [reverse proxy
setup](https://www.openproject.org/docs/installation-and-operations/installation/docker/#apache-reverse-proxy-setup).
Without this you will run into an `ERR_SSL_PROTOCOL_ERROR` when accessing OpenProject.

See below how to disable HTTPS.

Be aware that if you want to use the integrated Caddy proxy as a proxy with outbound connections, you need to rewrite the
`Caddyfile`. In the default state, it is configured to forward the `X-Forwarded-*` headers from the reverse proxy in
front of it and not setting them itself. This is considered a security flaw and should instead be solved by configuring
`trusted_proxies` inside the `Caddyfile`. For more information read
the [Caddy documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy).

### PORT

By default the port is bound to `0.0.0.0` means access to OpenProject will be public.
See below how to change that.

## Image configuration

OpenProject publishes `slim` containers that you should be using for this compose setup.
Please see https://www.openproject.org/docs/installation-and-operations/installation/docker/#available-containers for more information on the containers and versions we push.

## Configuration

Environment variables can be added to `docker-compose.yml` under `x-op-app -> environment` to change
OpenProject's configuration. Some are already defined and can be changed via the environment.

You can pass those variables directly when starting the stack as follows.

```
VARIABLE=value docker-compose up -d
```

You can also put those variables into an `.env` file in your current working
directory, and Docker Compose will pick it up automatically. See `.env.example`
for details.

## HTTPS

You can disable OpenProject's HTTPS option via:

```
OPENPROJECT_HTTPS=false
```

## PORT

If you want to specify a different port, you can do so with:

```
PORT=4000
```

If you don't want OpenProject to bind to `0.0.0.0` you can bind it to localhost only like this:

```
PORT=127.0.0.1:8080
```

## TAG

If you want to specify a custom tag for the OpenProject docker image, you can do so with:

```
TAG=my-docker-tag
```

## BIM edition

In order to install or change to BIM inside a Docker environment, please navigate to the [Docker Installation for OpenProject BIM](https://www.openproject.org/docs/installation-and-operations/bim-edition/#docker-installation-openproject-bim) paragraph at the BIM edition documentation.

## Upgrade

Retrieve any changes from the `openproject-docker-compose` repository:

    git pull origin stable/16

Build the control plane:

    docker-compose -f docker-compose.yml -f docker-compose.control.yml build

Take a backup of your existing postgresql data and openproject assets:

    docker-compose -f docker-compose.yml -f docker-compose.control.yml run backup

Run the upgrade:

    docker-compose -f docker-compose.yml -f docker-compose.control.yml run upgrade

Relaunch the containers, ensure you are pulling to use the latest version of the Docker images:

    docker compose up -d --build --pull always



## Backup

Switch off your current installation:

    docker-compose down

Build the control scripts:

    docker-compose -f docker-compose.yml -f docker-compose.control.yml build

Take a backup of your existing PostgreSQL data and OpenProject assets:

    docker-compose -f docker-compose.yml -f docker-compose.control.yml run backup

Restart your OpenProject installation

    docker-compose up -d



## Uninstall

If you want to stop the containers without removing them directly:

```bash
docker-compose stop
```

You can remove the container stack with:

```bash
docker-compose down
```

> [!NOTE]
> This will not remove your data which is persisted in named volumes, likely called `compose_opdata` (for attachments) and `compose_pgdata` (for the database).
> The exact name depends on the name of the directory where your `docker-compose.yml` and/or you `docker-compose.override.yml` files are stored (`compose` in this case).

If you want to start from scratch and remove the existing data you will have to remove these volumes via
`docker volume rm compose_opdata compose_pgdata`.

## Troubleshooting

You can look at the logs with:

    docker-compose logs -n 1000

For the complete documentation, please refer to https://docs.openproject.org/installation-and-operations/.

### Network issues

If you're running into weird network issues and timeouts such as the one described in
[OP#42802](https://community.openproject.org/work_packages/42802), you might have success in remove the two separate
frontend and backend networks. This might be connected to using podman for orchestration, although we haven't been able
to confirm this.

### SMTP setup fails: Network is unreachable.

Make sure your container has DNS resolution to access external SMTP server when set up as described in
[OP#44515](https://community.openproject.org/work_packages/44515).

```yml
worker:
  dns:
    - "Your DNS IP" # OR add a public DNS resolver like 8.8.8.8
```
