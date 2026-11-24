pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Colour palette for the shell.
 *
 * colourme owns the runtime file at
 * `$XDG_STATE_HOME/colourme/colours.json` (seeded by Home Manager from the
 * build-time render, then rewritten on every `colourme <scheme>`), and the
 * watched FileView below makes a scheme switch instant — no rebuild, no
 * restart, no post_hook.
 *
 * The JsonAdapter defaults are the committed fallback palette: the shell is
 * themed before the first seed/colourme run, and if the file is ever missing
 * or unparseable these values are used instead. Keep the keys and types in
 * sync with `configs/colourme/templates/quickshell.json`.
 */
Singleton {
    id: root

    readonly property string palettePath: {
        const state = Quickshell.env("XDG_STATE_HOME");
        const base = state && state.length > 0 ? state : Quickshell.env("HOME") + "/.local/state";
        return base + "/colourme/colours.json";
    }

    FileView {
        id: paletteFile
        path: root.palettePath
        watchChanges: true
        onFileChanged: reload()
        // A missing file before the first seed is expected, not an error.
        printErrors: false

        JsonAdapter {
            id: palette

            property string surfaceDefault: "#3c3836"
            property string surfaceLight: "#484341"
            property string surfaceOverlay: "#504945"
            property string foregroundDefault: "#ebdbb2"
            property string foregroundSubtle: "#928374"
            property string foregroundMuted: "#665c54"
            property string border: "#665c54"
            property string shadow: "#1d1d1d"
            property string critical: "#cc241d"
            property string accent: "#d79921"
            property string accentMuted: "#6c4c10"

            property string verm: "#bf8c2a"
            property string vermLit: "#e0a83a"
            property string flameCore: "#ffeac2"
            property string flameGlow: "#ffca63"
            property string flameInk: "#f0bd5b"
            property string flameEmber: "#7d5811"
            property string flameBurn: "#8a6113"
            property string flameTip: "#ffd78a"
        }
    }

    readonly property color surfaceDefault: palette.surfaceDefault
    readonly property color surfaceLight: palette.surfaceLight
    readonly property color surfaceOverlay: palette.surfaceOverlay
    readonly property color foregroundDefault: palette.foregroundDefault
    readonly property color foregroundSubtle: palette.foregroundSubtle
    readonly property color foregroundMuted: palette.foregroundMuted
    readonly property color border: palette.border
    readonly property color shadow: palette.shadow
    readonly property color critical: palette.critical
    readonly property color accent: palette.accent
    readonly property color accentMuted: palette.accentMuted

    readonly property color verm: palette.verm
    readonly property color vermLit: palette.vermLit
    readonly property color flameCore: palette.flameCore
    readonly property color flameGlow: palette.flameGlow
    readonly property string flameInk: palette.flameInk
    readonly property string flameEmber: palette.flameEmber
    readonly property string flameBurn: palette.flameBurn
    readonly property string flameTip: palette.flameTip
}
