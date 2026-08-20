#!/usr/bin/env bash
# Bootstrap Headscale context (users, tagged preauthkeys) required by acl.json
# Run this against your Headscale server (e.g. via `docker exec headscale ...`).
set -euo pipefail

HEADSCALE_BIN="${HEADSCALE_BIN:-headscale}"   # override to "docker exec headscale headscale" if containerized

ADMIN_USER="admin"
STANDARD_USER="citizen"

KEY_EXPIRATION="8760h"  # 1 year, adjust as needed

echo "== Creating users =="
$HEADSCALE_BIN users create "$ADMIN_USER" || echo "User $ADMIN_USER may already exist"
$HEADSCALE_BIN users create "$STANDARD_USER" || echo "User $STANDARD_USER may already exist"

echo "== Generating preauthkey for Traefik (tag:traefik) =="
TRAEFIK_KEY=$($HEADSCALE_BIN preauthkeys create --user 1 --expiration "$KEY_EXPIRATION" --tags tag:traefik | tail -n1)
echo "Traefik authkey: $TRAEFIK_KEY"

echo "== Generating preauthkey for backend services (tag:svc) =="
SVC_KEY=$($HEADSCALE_BIN preauthkeys create --user 1 --reusable --expiration "$KEY_EXPIRATION" --tags tag:svc | tail -n1)
echo "Service authkey: $SVC_KEY"

echo "== Generating preauthkey for backend services (tag:host) =="
HOST_KEY=$($HEADSCALE_BIN preauthkeys create --user 1 --expiration "$KEY_EXPIRATION" --tags tag:host | tail -n1)
echo "Host authkey: $HOST_KEY"

cat <<EOF

== Next steps ==

On the host:
  tailscale up --login-server https://localhost:9443 --authkey $HOST_KEY --advertise-routes=172.31.255.0/24 --hostname ztn

In you .env file:
SERVICE_PREAUTH_KEY=$SVC_KEY
TRAEFIK_PREAUTH_KEY=$TRAEFIK_KEY

To verify tags after registration:
  $HEADSCALE_BIN nodes list

EOF
