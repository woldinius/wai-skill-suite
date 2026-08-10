#!/usr/bin/env bash
# TEMPLATE — sits as /opt/app/deploy.sh on the server (chmod +x).
# Called by deploy-ssh.yml:  ./deploy.sh sha-<commit>
set -euo pipefail

TAG="${1:-latest}"
cd "$(dirname "$0")"

export IMAGE_TAG="$TAG"
COMPOSE="docker compose -f docker-compose.prod.yml"

echo ">> Pull image tag: $TAG"
$COMPOSE pull

echo ">> Run migrations"
# Migrate before the up (keep forward-/backward-compatible so rollback is possible).
# Example — adapt to migration tooling:
$COMPOSE run --rm api sh -c "npm run migrate:deploy" || { echo "Migration failed"; exit 1; }

echo ">> Start containers (rolling)"
$COMPOSE up -d --remove-orphans

echo ">> Check health"
sleep 5
$COMPOSE ps

echo ">> Clean up old images"
docker image prune -f

echo ">> Deploy $TAG done. Rollback: ./deploy.sh sha-<previous-commit>"
