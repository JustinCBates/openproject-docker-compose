# Deploying OpenProject on a VPS

This document shows a minimal, reproducible way to deploy this repository on a single VPS.

Overview
- Use the provided `docker-compose.yml` with `docker-compose.host.example.yml` to adapt paths and ports for a VPS.
- Keep secrets out of the repo; create a `.env.host` on the target host with `SECRET_KEY_BASE` and database credentials.
- Use the `scripts/deploy_vps.sh` helper to copy `.env.host` -> `.env`, create directories, and start the stack.

Quick steps

1. Clone to the VPS, e.g. `/opt/openproject`.
2. Copy `.env.example` to `.env.host`, edit values (OPENPROJECT_HOST__NAME, POSTGRES_PASSWORD, SECRET_KEY_BASE, OPDATA, PGDATA).
3. Create host directories and set ownership:

```bash
sudo mkdir -p /var/lib/openproject/pgdata /var/lib/openproject/opdata
sudo chown -R 1000:1000 /var/lib/openproject/opdata
```

4. Run the deploy helper:

```bash
./scripts/deploy_vps.sh
```

5. Optionally enable a systemd unit (not provided by default) that runs `docker compose up -d` at boot.

TLS
- If you expose ports 80/443, Caddy will attempt to obtain certificates automatically for the domain set in `OPENPROJECT_HOST__NAME`.
- Ensure DNS A/AAAA records point to the server before enabling HTTPS.

Rollbacks
- All changes are made in the `vps-deploy` git branch; to revert the repo you can `git checkout stable/16` locally or on the VPS to get back to the original state.
