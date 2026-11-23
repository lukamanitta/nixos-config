#!/usr/bin/env bash
#
# One-shot restic backup of the Arch home directory to Google Drive, run before
# shrinking the disk for the NixOS dual-boot install.
#
# Requires `restic` and `rclone` (run from a shell that has them, e.g.
#   nix shell nixpkgs#restic nixpkgs#rclone -c ./scripts/pre-nixos-backup.sh
# ) and an existing rclone remote named `gdrive` (`rclone config`).
#
# The repository password is read from RESTIC_PASSWORD_FILE (default
# ~/.config/restic/luka-workstation.pass). If that file does not exist, the
# script creates a random one and prints it once; store it in your password
# manager before continuing.
set -euo pipefail

REPO="${RESTIC_REPOSITORY:-rclone:gdrive:backups/luka-workstation}"
PASSFILE="${RESTIC_PASSWORD_FILE:-$HOME/.config/restic/luka-workstation.pass}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing: $1" >&2
    exit 1
  }
}
need restic
need rclone

if [ ! -f "$PASSFILE" ]; then
  mkdir -p "$(dirname "$PASSFILE")"
  umask 077
  openssl rand -base64 32 >"$PASSFILE"
  chmod 600 "$PASSFILE"
  echo "Created $PASSFILE. Store this password in your password manager:"
  cat "$PASSFILE"
  echo
fi

export RESTIC_REPOSITORY="$REPO"
export RESTIC_PASSWORD_FILE="$PASSFILE"

if ! restic snapshots >/dev/null 2>&1; then
  echo "Initialising restic repository at $REPO"
  restic init
fi

echo "Backing up $HOME to $REPO"
echo "Excluding caches, VM images, Flatpaks, toolchains and build outputs."

restic backup "$HOME" \
  --tag pre-nixos \
  --one-file-system \
  --exclude "$HOME/.cache" \
  --exclude "$HOME/.local/share/Trash" \
  --exclude "$HOME/.local/share/gnome-boxes" \
  --exclude "$HOME/.local/share/mise" \
  --exclude "$HOME/.local/share/pnpm" \
  --exclude "$HOME/.local/share/pipx" \
  --exclude "$HOME/.local/share/nvim" \
  --exclude "$HOME/.local/share/Steam" \
  --exclude "$HOME/.var" \
  --exclude "$HOME/Applications" \
  --exclude "$HOME/.AffinityLinux-Appimage" \
  --exclude "$HOME/.ollama" \
  --exclude "$HOME/.rustup" \
  --exclude "$HOME/.cargo" \
  --exclude "$HOME/.npm" \
  --exclude "$HOME/.zen" \
  --exclude "node_modules" \
  --exclude ".direnv" \
  --exclude "target" \
  --exclude "result" \
  --exclude "*.iso" \
  --exclude "*.qcow2" \
  --exclude "*.img"

restic snapshots --tag pre-nixos --latest 1

cat <<'EOF'

Backup complete. To inspect or restore:

  export RESTIC_REPOSITORY=rclone:gdrive:backups/luka-workstation
  export RESTIC_PASSWORD_FILE=~/.config/restic/luka-workstation.pass
  restic snapshots
  restic restore latest --target /tmp/restore

Keep a copy of the password and the snapshot ID somewhere outside this machine.
EOF
