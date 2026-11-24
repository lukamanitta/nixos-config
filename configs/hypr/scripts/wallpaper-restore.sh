#!/bin/sh
# Restore the wallpaper recorded in waypaper's state file.
#
# Waypaper asks `hyprctl monitors` for the outputs. Long-lived panes (herdr,
# tmux) keep the HYPRLAND_INSTANCE_SIGNATURE of the compositor they were
# started under, which may be gone after a Hyprland restart. `hyprctl
# instances` needs no signature, so point the command at the running
# compositor when the inherited one no longer answers.
state="${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/wallpaper.ini"
[ -s "$state" ] || exit 0

if ! hyprctl hyprpaper listactive >/dev/null 2>&1; then
    sig=$(hyprctl instances 2>/dev/null | awk -F'[: ]+' '/^instance /{print $2; exit}')
    if [ -n "$sig" ]; then
        HYPRLAND_INSTANCE_SIGNATURE="$sig"
        export HYPRLAND_INSTANCE_SIGNATURE
    fi
fi

# hyprpaper may still be starting: the autostart runs the service roles and
# late commands in one batch, so wait for its IPC socket.
i=0
while [ "$i" -lt 50 ]; do
    hyprctl hyprpaper listactive >/dev/null 2>&1 && break
    i=$((i + 1))
    sleep 0.1
done

exec waypaper --restore --state-file "$state"
