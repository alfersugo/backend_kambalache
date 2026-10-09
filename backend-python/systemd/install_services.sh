#!/usr/bin/env bash
# Install backend systemd services. Run with sudo.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Backend API services ──────────────────────────────────────────────────────
cp "$DIR/backend-python-api.service" /etc/systemd/system/
cp "$DIR/backend-bun-api.service"    /etc/systemd/system/

# ── AGE hardening validation (structural DB check, daily + on boot) ───────────
cp "$DIR/smtp-posix-age-hardening.service" /etc/systemd/system/
cp "$DIR/smtp-posix-age-hardening.timer"   /etc/systemd/system/

# ── AGE API continuity validation (API + RBAC check, every 12h + on boot) ─────
cp "$DIR/smtp-posix-age-api-continuity.service" /etc/systemd/system/
cp "$DIR/smtp-posix-age-api-continuity.timer"   /etc/systemd/system/

systemctl daemon-reload

systemctl enable backend-python-api.service backend-bun-api.service
systemctl enable smtp-posix-age-hardening.timer smtp-posix-age-api-continuity.timer

echo "Services installed and enabled."
echo "  Backend APIs  : systemctl start backend-python-api backend-bun-api"
echo "  AGE timers    : systemctl start smtp-posix-age-hardening.timer smtp-posix-age-api-continuity.timer"
