#!/usr/bin/env bash
# Ferme tous les ports publics sauf SSH (22), HTTP (80), HTTPS (443).
# Usage sur le VPS : sudo bash ~/SombaTeka/scripts/lock-vps-firewall.sh
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Lancez avec sudo."
  exit 1
fi

apt-get install -y ufw >/dev/null 2>&1 || true

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Autoriser le reseau Docker interne (nginx -> backend) sans ouvrir 8000/5432/6379 au public.
ufw allow in on docker0 >/dev/null 2>&1 || true

echo "y" | ufw enable
ufw status verbose

echo ""
echo "Ports publics autorises : 22, 80, 443 uniquement."
echo "8000, 5432, 6379 et autres ports sensibles : fermes depuis Internet."
