# OpenProject installation with Docker Compose

This repository contains the installation method for OpenProject using Docker Compose.

> [!NOTE]
> Looking for the Kubernetes installation method?
> Please use the [OpenProject helm chart](https://charts.openproject.org) to install OpenProject on Kubernetes.

## Quick start

First, clone the `openproject-docker-compose` repository:

```shell
git clone https://github.com/opf/openproject-docker-compose.git --depth=1 --branch=stable/16 openproject
```

Copy the example `.env` file and edit any values you want to change:

```shell
cp .env.example .env
vim .env
```

If you are using the default value of `OPDATA` from `.env.example`, ensure the folder exists and has the right permissions:

```shell
sudo mkdir -p /var/openproject/assets
sudo chown 1000:1000 -R /var/openproject/assets
```

Start the containers in the background and pull latest images (recommended):

```shell
OPENPROJECT_HTTPS=false docker compose up -d --build --pull=always
```

After a short time, OpenProject should be available on `http://localhost:8080`. The default credentials are `admin` / `admin`.

`OPENPROJECT_HTTPS=false` disables HTTPS behavior for initial startup (recommended for simple local testing). For production, run OpenProject behind a TLS-terminating proxy and remove this flag.

### Customization

Prefer local overrides to keep host-specific configuration out of version control. Use `docker-compose.override.yml` for local changes (this file is intentionally ignored in the repo):

```bash
cp docker-compose.override.example.yml docker-compose.override.yml
# edit docker-compose.override.yml and .env as needed
```

See the official Docker Compose docs for how overrides work: https://docs.docker.com/compose/extends/

### Local per-host environment files

If you want host-specific examples, keep a sanitized example in the repo (no secrets), e.g. `.env.hostinger.example`. For local use, copy the tracked example:

```bash
cp .env.hostinger.vps .env
```

Then start the stack as usual:

```bash
docker compose up -d --build --pull=always
```

### Troubleshooting

If you see a warning like "pull access denied for openproject/proxy..." after `docker compose up`, it is usually safe to ignore. If this occurs during `docker compose pull` the command may return a non-zero exit code even though other images were pulled. Consider:

```bash
docker compose pull --ignore-buildable
```

## HTTPS / TLS

OpenProject assumes HTTPS in production by default. You can disable the internal HTTPS mode for local testing:

```bash
OPENPROJECT_HTTPS=false
```

For production, terminate TLS at a reverse proxy (Nginx, Apache, or Caddy). If you use the integrated Caddy proxy, be careful to configure `trusted_proxies` and `X-Forwarded-*` headers appropriately. See the Caddy docs: https://caddyserver.com/docs/caddyfile/directives/reverse_proxy

## Ports and binding

By default the service binds to `0.0.0.0` (publicly reachable). To change the port or listen address, set `PORT` in your `.env`:

```bash
# bind to a different port
PORT=4000

# or bind only to localhost
PORT=127.0.0.1:8080
```

## Image configuration and TAG

OpenProject publishes `slim` containers suitable for this compose setup. To use a different image tag set `TAG` in `.env`:

```bash
TAG=16-slim
# or
TAG=my-docker-tag
```

## BIM edition

See the BIM documentation for Docker instructions: https://www.openproject.org/docs/installation-and-operations/bim-edition/#docker-installation-openproject-bim

## Upgrade

Retrieve changes from the repo and rebuild control plane:

```bash
git pull origin stable/16
docker compose -f docker-compose.yml -f docker-compose.control.yml build
```

Take a backup of PostgreSQL data and OpenProject assets (control plane):

```bash
docker compose -f docker-compose.yml -f docker-compose.control.yml run backup
```

Run the upgrade:

```bash
docker compose -f docker-compose.yml -f docker-compose.control.yml run upgrade
```

Relaunch containers (pulling latest images):

```bash
docker compose up -d --build --pull=always
```

## Backup

Stop the stack, build control scripts, and take a backup:

```bash
docker compose down
docker compose -f docker-compose.yml -f docker-compose.control.yml build
docker compose -f docker-compose.yml -f docker-compose.control.yml run backup
```

Restart the stack:

```bash
docker compose up -d
```

## Uninstall

Stop containers without removing data:

```bash
docker compose stop
```

Remove containers (volumes not removed):

```bash
docker compose down
```

To remove data volumes (start from scratch):

```bash
docker volume rm compose_opdata compose_pgdata
```

## Troubleshooting commands

Tail recent logs for a service:

```bash
docker compose logs --tail 200 web
```

Check container health via HTTP probe (from host):

```bash
curl -fsS -o /dev/null -w "%{http_code}" http://localhost:8080/StatesmenProjects/health_checks/default || true
```

If you see networking or DNS issues with worker containers, you can add DNS entries via compose:

```yml
worker:
  dns:
    - "YOUR_DNS_IP"
```

---

*For full documentation and operational guidance see https://docs.openproject.org/installation-and-operations/*
