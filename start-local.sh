#!/usr/bin/env bash
# Starts the backend locally with the demo profile.
# Usage: ./start-local.sh

set -e
cd "$(dirname "$0")"

# Export vars from .env line by line (handles special chars, skips comments and blanks)
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  [[ "$line" != *=* ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  [[ "$key" == GOOGLE_CREDENTIALS_JSON ]] && continue  # loaded from file below
  export "$key=$value"
done < .env

# Load Google credentials from file (avoids shell escaping issues with JSON)
if [ -f .google-credentials.json ]; then
  export GOOGLE_CREDENTIALS_JSON="$(cat .google-credentials.json)"
  echo "[local] Google credentials loaded from .google-credentials.json"
else
  echo "[local] WARNING: .google-credentials.json not found — Sheets integration disabled"
fi

exec ./mvnw spring-boot:run -Dspring-boot.run.profiles=demo
