#!/usr/bin/env bash
# bootstrap.sh — installs Ansible and runs main.yml
#
# Usage A – files already on this machine (SCP or git clone):
#   sudo bash bootstrap.sh
#   (main.yml must be in the same directory as bootstrap.sh)
#
# Usage B – pull main.yml directly from GitHub:
#   curl -fsSL <raw-url>/bootstrap.sh | sudo bash
#   (set GITHUB_USER / REPO / BRANCH below first)
set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
GITHUB_USER="jediBui"
REPO="ubuntu-setup"
BRANCH="main"
PLAYBOOK_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO}/${BRANCH}/main.yml"
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
  curl \
  wget \
  gnupg2 \
  ca-certificates \
  software-properties-common \
  apt-transport-https

# Ensure community.general collection is available (provides apt_repository)
if ! ansible-galaxy collection list 2>/dev/null | grep -q "community.general"; then
  info "Installing community.general Ansible collection..."
  ansible-galaxy collection install community.general --upgrade -q
fi

# ── RESOLVE PLAYBOOK ──────────────────────────────────────────────────────────
mkdir -p "$(dirname "$PLAYBOOK_PATH")"

# Check for a local main.yml in the same dir as this script OR in $PWD.
# The BASH_SOURCE trick does NOT work when piped through curl, so we check
# both locations so the local-SCP workflow still functions.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || true)"
LOCAL_PLAYBOOK=""
for candidate in "${SCRIPT_DIR}/main.yml" "${PWD}/main.yml"; do
  if [[ -f "$candidate" ]]; then
    LOCAL_PLAYBOOK="$candidate"
    break
  fi
done

if [[ -n "$LOCAL_PLAYBOOK" ]]; then
  info "Found local main.yml at ${LOCAL_PLAYBOOK} — using it."
  cp "$LOCAL_PLAYBOOK" "$PLAYBOOK_PATH"
  ok "Using local playbook."
else
  info "Downloading main.yml from GitHub..."
  if ! curl -fsSL "$PLAYBOOK_URL" -o "$PLAYBOOK_PATH"; then
    die "Download failed. Verify that main.yml is pushed to:
  https://github.com/${GITHUB_USER}/${REPO}/blob/${BRANCH}/main.yml
  OR copy main.yml to this directory and re-run: sudo bash bootstrap.sh"
  fi
  ok "Playbook downloaded."
fi

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
echo "  3. Set RDP credentials (required before first remote connection):"
echo "       grdctl rdp set-credentials <username> <password>"
echo "  4. Connect via RDP on port 3389 — GNOME Remote Desktop shares your session."
echo "  5. Font/gsettings changes take effect on your next graphical login."
echo
