#!/usr/bin/env bash
# Create Kanidm person accounts required for Headscale ACL (admin + user)
# Run this on a machine with the `kanidm` CLI configured to reach your instance,
# or via: docker exec -it kanidm kanidm ...
set -euo pipefail

KANIDM_BIN="${KANIDM_BIN:-kanidm}"   # override to "docker exec kanidm kanidm" if containerized
ADMIN_NAME_FLAG="--name idm_admin"   # login identity used to perform admin actions

DOMAIN="${KANIDM_MAIL_DOMAIN:-email.localhost}"

declare -A USERS=(
  ["citizen"]="Standard User"
)

echo "== Logging in as idm_admin (interactive password prompt) =="
$KANIDM_BIN login --name idm_admin

for username in "${!USERS[@]}"; do
  displayname="${USERS[$username]}"
  echo "== Creating person: $username ($displayname) =="
  $KANIDM_BIN person create "$username" "$displayname" $ADMIN_NAME_FLAG || \
    echo "  -> $username may already exist, skipping create"

  echo "== Setting email for $username =="
  $KANIDM_BIN person update "$username" --mail "${username}@${DOMAIN}" $ADMIN_NAME_FLAG

  echo "== Generating credential reset token for $username =="
  RESET_OUTPUT=$($KANIDM_BIN person credential create-reset-token "$username" $ADMIN_NAME_FLAG)
  echo "$RESET_OUTPUT"
  echo "  -> Share this reset link with $username (or open it yourself) to set password/TOTP."
  echo
done

echo "== Creating group headscale_users =="
$KANIDM_BIN group create headscale_users $ADMIN_NAME_FLAG || echo "  -> group may already exist"

for username in "${!USERS[@]}"; do
  echo "== Adding $username to headscale_users =="
  $KANIDM_BIN group add-members headscale_users "$username" $ADMIN_NAME_FLAG
done

echo
echo "== Verification =="
for username in "${!USERS[@]}"; do
  $KANIDM_BIN person get "$username" $ADMIN_NAME_FLAG
done
$KANIDM_BIN group list-members headscale_users $ADMIN_NAME_FLAG

cat <<EOF

== Done ==
Users created: ${!USERS[@]}
Group: headscale_users

Next: run kanidm-configure-headscale-oidc.sh to set up the OAuth2 client,
then configure config.yaml on Headscale with the returned client_secret.
EOF
