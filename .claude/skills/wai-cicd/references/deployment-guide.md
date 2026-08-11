# Server Deployment Runbook (GitHub-native, any Linux host)

> Reference knowledge for `wai-cicd`. When setting up in a target project, this becomes
> a tailored `docs/deploy/server-deployment.md`. The model is fixed and GitHub-native:
> registry **GHCR**, pipeline **GitHub Actions**, reverse proxy **Caddy**, deploy
> **Docker Compose over SSH** to your own Linux server, whatever the provider.

## The base

1. **Containerization** — `Dockerfile` per deployable app (multi-stage: build → slim
   runtime image), `.dockerignore`. Non-root `USER`, fixed base image tags.
2. **Image registry — GHCR** (`ghcr.io/<owner>/<repo>-<app>`). Auth in Actions via
   `GITHUB_TOKEN` with `permissions: packages: write`. Tags: `sha-<commit>` (immutable,
   for rollback) + `latest`/branch.
3. **CI gates** — lint, type-check, tests run **before** build/push. Red = no deploy.
4. **Health endpoints** — `/health` (liveness) and `/ready` (readiness, including DB check).
   Basis for healthcheck/zero-downtime (`RES-5`).
5. **Secrets** — never in the image/repo (`SEC-3`). Build args only for non-secret things.
   Runtime secrets via server `.env` (root-only) or GitHub Actions secrets.
6. **Migrations** — separate step before/at deploy; forward- and backward-compatible,
   so a rollback doesn't fail on the database.
7. **Backups & DR** (`RES-6`) — DB dump regularly to off-host object storage (S3-compatible), restore
   played through at least once.
8. **Rollback** — redeploy of a previous `sha-` tag. Therefore never build only on `latest`.

## 1. Provision & harden the server

- A Linux VM at your provider (Ubuntu LTS), SSH public key deployed at creation.
- The provider's **cloud firewall**: only 22 (better on a custom port + source IP restriction),
  80, 443 open.
- On the server:
  ```bash
  # as root
  adduser deploy && usermod -aG sudo deploy
  rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy   # copy the SSH key across
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/; s/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart ssh
  apt-get update && apt-get install -y ufw fail2ban unattended-upgrades
  ufw default deny incoming && ufw allow 22 && ufw allow 80 && ufw allow 443 && ufw --force enable
  ```

## 2. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
usermod -aG docker deploy
```
(The Compose plugin is included in a current Docker installation: `docker compose`.)

## 3. App directory & reverse proxy

- `/opt/app/` with `docker-compose.prod.yml`, `Caddyfile`, `.env` (chmod 600, deploy:deploy).
- **Caddy** terminates HTTPS and fetches Let's Encrypt certificates automatically (only one
  domain to enter in the `Caddyfile`). Alternatively Traefik, if label-based routing
  is wanted.

## 4. Deploy mechanism (Compose over SSH)

- GitHub Actions builds + pushes the image (`ci.yml`), then a deploy job SSHes to the
  server and calls `deploy.sh <tag>` (`deploy-ssh.yml`).
- `deploy.sh`: `docker compose pull` → `docker compose up -d` → migration → `docker image prune`.
- The image tag is passed to Compose via `IMAGE_TAG` env.

**Required GitHub Actions secrets:** `SSH_HOST`, `SSH_USER` (deploy), `SSH_KEY`
(private deploy key), optionally `SSH_PORT`. GHCR auth runs via `GITHUB_TOKEN`.

## 5. Operation

- **Logs:** `docker compose logs -f`. Optionally Uptime-Kuma/Grafana-Loki as an add-on stack.
- **Backups:** cron on the server, `pg_dump | gzip` → Storage Box (rclone/scp).
- **Updates:** `unattended-upgrades` for the OS; app updates via the pipeline.
- **Rollback:** rerun the deploy with a previous `sha-` tag
  (`IMAGE_TAG=sha-<old> docker compose up -d`).
