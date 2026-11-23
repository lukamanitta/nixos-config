#!/usr/bin/env bash
#
# Free space on the Arch install before shrinking its btrfs filesystem for the
# NixOS dual-boot phase. Defaults to a dry run; pass --apply to delete.
#
# Safe-to-delete: re-downloadable caches, the DaVinci AUR build tree, ollama
# models (not used), Trash, and the journal. Kept: personal data, the test VM
# images, the old Affinity Wine prefix, Flatpaks, /opt/rocm and /opt/resolve.
set -euo pipefail

APPLY=0
NIX_GC=0
DAVINCI_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --nix-gc) NIX_GC=1 ;;
    --davinci-build) DAVINCI_BUILD=1 ;;
    -h | --help)
      echo "usage: $0 [--apply] [--nix-gc] [--davinci-build]"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

run() {
  printf '  + %s\n' "$*"
  if ((APPLY)); then
    "$@"
  fi
}

size() {
  du -sh "$1" 2>/dev/null | cut -f1 || true
}

echo "== Arch cleanup (dry run unless --apply) =="
echo "home: $(df -h --output=used,pcent /home | tail -1)"

# 1. Trash -----------------------------------------------------------------
if [ -d "$HOME/.local/share/Trash" ]; then
  echo "Trash: $(size "$HOME/.local/share/Trash")"
  for trashdir in files info; do
    [ -d "$HOME/.local/share/Trash/$trashdir" ] \
      && run find "$HOME/.local/share/Trash/$trashdir" -mindepth 1 -delete
  done
fi

# 2. Re-downloadable build caches ------------------------------------------
if [ -d "$HOME/Applications/.builds/davinci-resolve" ]; then
  echo "DaVinci build tree: $(size "$HOME/Applications/.builds/davinci-resolve")"
  if ((DAVINCI_BUILD)); then
    run rm -rf "$HOME/Applications/.builds/davinci-resolve"
  else
    echo "  keeping it: the nixpkgs Resolve source fetch currently fails; pass"
    echo "  --davinci-build once Resolve is proven on NixOS."
  fi
fi

if command -v npm >/dev/null 2>&1; then
  echo "npm cache: $(size "$HOME/.npm")"
  if ((APPLY)); then npm cache clean --force; else echo "  + npm cache clean --force"; fi
else
  run rm -rf "$HOME/.npm"
fi

if command -v paru >/dev/null 2>&1; then
  echo "paru cache: $(size "$HOME/.cache/paru")"
  if ((APPLY)); then paru -Scc --noconfirm; else echo "  + paru -Scc --noconfirm"; fi
else
  run rm -rf "$HOME/.cache/paru"
fi

for cache in winetricks ms-playwright pip uv chromium; do
  path="$HOME/.cache/$cache"
  [ -e "$path" ] || continue
  echo ".cache/$cache: $(size "$path")"
  run rm -rf "$path"
done

# 3. ollama models (not used on the NixOS plan) ----------------------------
if [ -d "$HOME/.ollama/models" ]; then
  echo "ollama models: $(size "$HOME/.ollama/models")"
  run rm -rf "$HOME/.ollama/models"
fi

# 4. Journal ---------------------------------------------------------------
echo "system journal: $(journalctl --disk-usage 2>/dev/null | tail -1 || echo unknown)"
if ((APPLY)); then
  sudo journalctl --vacuum-size=200M
else
  echo "  + sudo journalctl --vacuum-size=200M"
fi

# 5. Nix store (optional; rebuilds the dev shells afterwards) --------------
if ((NIX_GC)); then
  echo "Nix store: $(size /nix/store)"
  if ((APPLY)); then nix-collect-garbage -d; else echo "  + nix-collect-garbage -d"; fi
fi

# 6. Snapshots: review manually --------------------------------------------
echo
echo "Snapper snapshots are not deleted automatically. Review with:"
echo "  snapper list --columns number,date,type,description"
echo "Keep a recent snapshot plus one taken immediately before the NixOS install, then:"
echo "  sudo snapper delete <numbers>"

echo
echo 'Kept on purpose: ~/.local/share/gnome-boxes (test VM), ~/.var (Flatpaks),'
echo "$HOME/.AffinityLinux-Appimage (old prefix), /opt/rocm, /opt/resolve, personal data."
((APPLY)) || echo "No changes made. Re-run with --apply after reviewing."
