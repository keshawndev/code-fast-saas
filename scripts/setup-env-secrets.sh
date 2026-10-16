#!/usr/bin/env bash
# Seed one environment's app secrets in SSM Parameter Store.
#
#   scripts/setup-env-secrets.sh staging
#
# - Copies the secrets every environment shares (Google OAuth client, Resend,
#   Stripe test key) from dev.
# - Generates a new AUTH_SECRET for this environment.
# - Prompts for this environment's MONGO_URI (input is hidden).
# - Creates this environment's Stripe webhook endpoint (skipped if one already
#   exists for the URL) and stores its signing secret.
#
# No secret value is printed or written to disk. Requires: aws (logged in),
# stripe (logged in to the same account as STRIPE_API_KEY), python3, openssl.
# Running tasks only pick up new values on their next deployment.
set -euo pipefail

ENV="${1:?usage: $0 <staging|prod>}"
SRC=dev
PREFIX=/code-fast-saas

case "$ENV" in
  staging) DOMAIN=staging.project1.keshawnbarbary.com ;;
  prod) DOMAIN=project1.keshawnbarbary.com ;;
  *) echo "unknown environment: $ENV" >&2; exit 1 ;;
esac
WEBHOOK_URL="https://$DOMAIN/api/webhook"

get() {
  aws ssm get-parameter --name "$PREFIX/$SRC/$1" --with-decryption \
    --query Parameter.Value --output text
}

put() {
  aws ssm put-parameter --name "$PREFIX/$ENV/$1" --type SecureString \
    --value "$2" --overwrite --query Version --output text > /dev/null
  echo "  $1: stored"
}

echo "Seeding $PREFIX/$ENV/ ..."

for name in GOOGLE_ID GOOGLE_SECRET RESEND_KEY STRIPE_API_KEY; do
  put "$name" "$(get "$name")"
done

put AUTH_SECRET "$(openssl rand -base64 32)"

read -rsp "MONGO_URI for $ENV (input hidden): " MONGO
echo
put MONGO_URI "$MONGO"
unset MONGO

EXISTING=$(stripe webhook_endpoints list 2> /dev/null |
  python3 -c "import sys,json; print(next((e['id'] for e in json.load(sys.stdin)['data'] if e['url']=='$WEBHOOK_URL'), ''))")

if [ -n "$EXISTING" ]; then
  echo "  Stripe webhook for $WEBHOOK_URL already exists ($EXISTING); signing secret left as is"
else
  RESPONSE=$(stripe webhook_endpoints create -d url="$WEBHOOK_URL" \
    -d "enabled_events[]=checkout.session.completed" \
    -d "enabled_events[]=customer.subscription.deleted" 2> /dev/null)
  put STRIPE_WEBHOOK_SECRET "$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['secret'])")"
  echo "  Stripe webhook created: $(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
fi

echo "Done. Parameters in $PREFIX/$ENV/:"
aws ssm get-parameters-by-path --path "$PREFIX/$ENV" \
  --query "Parameters[].Name" --output text | tr '\t' '\n'
