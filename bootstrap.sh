#!/usr/bin/env bash
# bootstrap.sh — installs Ansible and runs main.yml from GitHub
# Usage: curl -fsSL <raw-url>/bootstrap.sh | sudo bash
#   or:  sudo bash bootstrap.sh
set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
# Edit GITHUB_USER and REPO if you fork this playbook.
GITHUB_USER="jediBui"
REPO="dotfiles-servers"
BRANCH="main"
PLAYBOOK_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO}/${BRANCH}/ubuntu-setup/main.yml"
PLAYBOOK_PATH="/tmp/ubuntu-bootstrap/main.yml"

# ── HELPERS ───────────────────────────────────────────────────────────────────
info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m  %s\n' "$*"; }
die()   { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*" >&2; exit 1; }

# ── ROOT CHECK ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root: sudo bash bootstrap.sh"

# ── INSTALL PREREQUISITES ────────────────────────────────────────────────────
info "Updating apt cache..."
apt-get update -qq

info "Installing Ansible and dependencies..."
apt-get install -y -qq \
  ansible \
  python3 \
  python3-pip \
  curl \
  wget \
  gnupg2 \
  ca-certificates \
  software-properties-common \
  apt-transport-https

# Ensure community.general collection is available (provides apt_repository, ufw)
if ! ansible-galaxy collection list 2>/dev/null | grep -q "community.general"; then
  info "Installing community.general Ansible collection..."
  ansible-galaxy collection install community.general --upgrade -q
fi

# ── DOWNLOAD PLAYBOOK ─────────────────────────────────────────────────────────
info "Downloading main.yml from GitHub..."
mkdir -p "$(dirname "$PLAYBOOK_PATH")"
curl -fsSL "$PLAYBOOK_URL" -o "$PLAYBOOK_PATH" \
  || die "Failed to download playbook from: $PLAYBOOK_URL"
ok "Playbook saved to $PLAYBOOK_PATH"

# ── RUN ANSIBLE ───────────────────────────────────────────────────────────────
info "Running Ansible playbook..."
ansible-playbook "$PLAYBOOK_PATH" \
  --connection=local \
  --inventory "localhost," \
  --diff

# ── DONE ──────────────────────────────────────────────────────────────────────
ok "Bootstrap complete."
echo
echo "  Next steps:"
echo "  1. Log out and back in so zsh becomes your active shell."
echo "  2. Run 'nordvpn login' to authenticate NordVPN."
echo "  3. Connect via RDP on port 3389 (xrdp is running)."
echo "  4. gsettings font changes take effect on your next graphical login."
echo
