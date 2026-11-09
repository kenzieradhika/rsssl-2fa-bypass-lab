#!/usr/bin/env bash
# Fetch plugin versions used by the lab (not committed to git).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p plugins
for pv in really-simple-ssl.9.5.6 really-simple-ssl.9.5.11 elementor.3.25.4; do
  [ -f "plugins/$pv.zip" ] && continue
  curl -sSL --max-time 300 "https://downloads.wordpress.org/plugin/$pv.zip" -o "plugins/$pv.zip"
  echo "fetched $pv.zip"
done
