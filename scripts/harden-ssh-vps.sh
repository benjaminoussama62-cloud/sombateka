#!/usr/bin/env bash
# Desactive la connexion SSH par mot de passe (cle uniquement).
# A lancer UNIQUEMENT apres setup-ssh-key-vps.ps1 OK.
# Gardez l'acces console du hebergeur (DigitalOcean) en secours.

set -euo pipefail

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 localhost "echo ok" 2>/dev/null; then
  : # pas de test local obligatoire
fi

if [ ! -f /etc/ssh/sshd_config ]; then
  echo "Erreur: /etc/ssh/sshd_config introuvable"
  exit 1
fi

TS=$(date +%Y%m%d-%H%M%S)
cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak-$TS"
echo "Sauvegarde: /etc/ssh/sshd_config.bak-$TS"

# Fichier drop-in (prioritaire sur Debian/Ubuntu recents)
DROPIN="/etc/ssh/sshd_config.d/99-sombateka-hardening.conf"
mkdir -p /etc/ssh/sshd_config.d
cat > "$DROPIN" <<'EOF'
# SombaTeka — cle SSH uniquement (pas de mot de passe)
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin prohibit-password
MaxAuthTries 3
EOF
chmod 644 "$DROPIN"
echo "Ecrit: $DROPIN"

if ! sshd -t; then
  echo "Config SSH invalide — restauration..."
  rm -f "$DROPIN"
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl reload ssh 2>/dev/null || systemctl reload sshd
else
  service ssh reload 2>/dev/null || service sshd reload
fi

echo ""
echo "OK — mot de passe SSH desactive."
echo "Connexion possible uniquement avec une cle autorisee dans ~/.ssh/authorized_keys"
echo ""
grep -E '^(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin)' "$DROPIN" || true
