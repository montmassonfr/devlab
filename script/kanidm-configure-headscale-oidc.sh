#!/usr/bin/env bash
# Configure Kanidm as an OIDC provider for Headscale
# Run this AFTER kanidm-create-users.sh has created the users/group.
set -euo pipefail

KANIDM_BIN="${KANIDM_BIN:-kanidm}"   # override to "docker exec kanidm kanidm" if containerized
ADMIN_NAME_FLAG="--name idm_admin"

OAUTH2_CLIENT_NAME="headscale"
OAUTH2_DISPLAY_NAME="Headscale"
HEADSCALE_URL="${HEADSCALE_URL:-https://localhost:8443}"
REDIRECT_URI="${HEADSCALE_URL}/oidc/callback"
SCOPE_GROUP="headscale_users"

echo "== Logging in as idm_admin (interactive password prompt) =="
$KANIDM_BIN login --name idm_admin

echo "== Creating OAuth2 client: $OAUTH2_CLIENT_NAME =="
$KANIDM_BIN system oauth2 create "$OAUTH2_CLIENT_NAME" "$OAUTH2_DISPLAY_NAME" "$REDIRECT_URI" $ADMIN_NAME_FLAG || \
  echo "  -> client may already exist, skipping create"

echo "== Mapping scopes (openid profile email) for group $SCOPE_GROUP =="
# NOTE: scopes must be passed as separate space-separated arguments, NOT comma-separated,
# otherwise Kanidm rejects it with "Invalid Oauth Scope Map syntax".
$KANIDM_BIN system oauth2 update-scope-map "$OAUTH2_CLIENT_NAME" "$SCOPE_GROUP" openid profile email groups $ADMIN_NAME_FLAG

echo "== Preferring short username (avoids SPN in preferred_username) =="
$KANIDM_BIN system oauth2 prefer-short-username "$OAUTH2_CLIENT_NAME" $ADMIN_NAME_FLAG

echo "== Retrieving client secret =="
CLIENT_SECRET=$($KANIDM_BIN system oauth2 show-basic-secret "$OAUTH2_CLIENT_NAME" $ADMIN_NAME_FLAG)

cat <<EOF

== Done ==

OAuth2 client "$OAUTH2_CLIENT_NAME" is configured in Kanidm.

Client secret: $CLIENT_SECRET

Add this to Headscale's config.yaml:

oidc:
  issuer: "https://<your-kanidm-domain>/oauth2/openid/$OAUTH2_CLIENT_NAME"
  client_id: "$OAUTH2_CLIENT_NAME"
  client_secret: "$CLIENT_SECRET"
  scope: ["openid", "profile", "email","groups"]
  pkce:
    enabled: true
    method: "S256"
  allowed_groups:
    - "$SCOPE_GROUP@<your-kanidm-domain>"

Restart Headscale after updating config.yaml:
  systemctl restart headscale
  # or: docker restart headscale

Then test registration with:
  tailscale up --login-server $HEADSCALE_URL
EOF
