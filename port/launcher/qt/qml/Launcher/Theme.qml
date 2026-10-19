pragma Singleton
import QtQuick
import Launcher

// Every color, size and font of the launcher lives here (single source for the visual identity).
QtObject {
    // surfaces
    readonly property color bg: "#111418"
    readonly property color rail: "#0c0e11"
    readonly property color railLine: "#22272e"
    readonly property color navHover: "#1b1f24"
    readonly property color navOn: "#f2f3f5"
    readonly property color navOnLine: "#f2f3f5"
    readonly property color card: "#1b1f24"
    readonly property color cardLine: "#2a3038"
    readonly property color chip: "#1b1f24"
    readonly property color chipLine: "#323943"
    readonly property color ghost: "#1b1f24"
    readonly property color ghostHover: "#252a31"
    readonly property color ghostLine: "#353c46"
    readonly property color ghostLineHover: "#4a525c"
    // text
    readonly property color text: "#f2f3f5"
    readonly property color textSoft: "#d0d4da"
    readonly property color textChip: "#d0d4da"
    readonly property color textMuted: "#a3abb5"
    readonly property color textDim: "#97a0aa"
    readonly property color textFaint: "#8a929c"
    // states
    readonly property color ok: "#2fbf71"
    readonly property color warn: "#b86e00"   // amber: white badge text still readable
    readonly property color bad: "#e5484d"
    // on fills and controls
    readonly property color title: "#f5f6f8"      // headings and values on the page and on cards
    readonly property color onAccent: "#ffffff"   // text on accent, state and disabled fills
    readonly property color onNav: "#111418"      // text on the black pill of the current item
    readonly property color well: "#0b0d10"       // inputs, logs, image wells
    readonly property color track: "#3a414a"      // switch and slider tracks
    readonly property color trackLine: "#4a525c"
    readonly property color knob: "#ffffff"
    readonly property color disabledFill: "#2a3038"
    readonly property color disabledText: "#8a929c"
    readonly property color off: "#5f6773"
    // one accent per section
    readonly property color smoke: "#e2412e"  // Play, Fixes
    readonly property color video: "#4d8bff"  // Graphics
    readonly property color neon: "#e2412e"   // Controls
    readonly property color cyan: "#4d8bff"   // Support
    readonly property var accents: ({ library: "#e2412e", play: "#e2412e", graphics: "#e2412e", controls: "#e2412e",
                                      fixes: "#e2412e", saves: "#e2412e", guides: "#e2412e", support: "#e2412e",
                                      updates: "#e2412e", advanced: "#e2412e", mods: "#e2412e" })
    // type
    property string fontDisplay: Backend.fontDisplay
    property string fontText: Backend.fontText
    readonly property int railWidth: 236
    readonly property int heroHeight: 320
    // line icons, 24x24 viewBox (circles written as arcs)
    readonly property var icons: ({
        library: "M4 4h6v6H4z M14 4h6v6h-6z M4 14h6v6H4z M14 14h6v6h-6z",
        play: "M7 4.5v15l12-7.5z",
        graphics: "M4 7h10M18 7h2M4 17h2M10 17h10 M18 7a2 2 0 1 0-4 0a2 2 0 1 0 4 0 M10 17a2 2 0 1 0-4 0a2 2 0 1 0 4 0",
        controls: "M7 8h10a4 4 0 0 1 4 4l-1 5a2 2 0 0 1-3.4 1L15 16H9l-1.6 2A2 2 0 0 1 4 17l-1-5a4 4 0 0 1 4-4z",
        fixes: "M12 3l8 3v6c0 4.5-3.2 7.8-8 9-4.8-1.2-8-4.5-8-9V6z M8.5 12l2.5 2.5 4.5-5",
        guides: "M7 8h10a4 4 0 0 1 4 4l-1 5a2 2 0 0 1-3.4 1L15 16H9l-1.6 2A2 2 0 0 1 4 17l-1-5a4 4 0 0 1 4-4z M8 10.5v3M6.5 12h3 M15.5 11.5h.01M17.5 13.5h.01",
        saves: "M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z M12 10.5v5M9.5 13.5 12 16l2.5-2.5",
        support: "M21 12a9 9 0 1 0-18 0a9 9 0 1 0 18 0 M15.5 12a3.5 3.5 0 1 0-7 0a3.5 3.5 0 1 0 7 0 M5.6 5.6l3.9 3.9M14.5 14.5l3.9 3.9M18.4 5.6l-3.9 3.9M9.5 14.5l-3.9 3.9",
        updates: "M12 4v11M7.5 11 12 15.5 16.5 11M5 20h14",
        advanced: "M4 6h16M4 12h16M4 18h16 M9 6a2 2 0 1 0-4 0a2 2 0 1 0 4 0 M19 12a2 2 0 1 0-4 0a2 2 0 1 0 4 0 M12 18a2 2 0 1 0-4 0a2 2 0 1 0 4 0",
        mods: "M6 9h12a3 3 0 0 1 0 6H6a3 3 0 0 1 0-6z M17.2 12a2.2 2.2 0 1 0-4.4 0a2.2 2.2 0 1 0 4.4 0"
    })

    // Translation: reading Backend.lang inside makes every binding that calls it re-evaluate
    // when the player switches language.
    function tr(key) { var l = Backend.lang; return Backend.t(key) }
}
