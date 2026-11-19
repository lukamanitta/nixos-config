#!/bin/sh
mon=$(hyprctl activeworkspace -j | jq -r '.monitor')
# quickshell ipc call pill "$1" "$mon"
quickshell ipc call pill "$1" "$mon"
