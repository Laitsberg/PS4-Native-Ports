import QtQuick
import QtQuick.Dialogs
import Launcher

// The home screen: one 2:3 cover per game folder the player added (the dump's own pic1/icon0
// art, else the title on a colored card), and on the right the chosen game with Play.
Item {
    id: page
    signal openLog()
    readonly property color accent: Theme.accents.library
    readonly property int tileW: 150
    readonly property int tileH: 225
    readonly property var placeholders: ["#2b2d6e", "#2a2d33", "#8a6d12", "#1f4a3d", "#5a2340"]
    readonly property var game: {
        var games = Backend.library
        for (var i = 0; i < games.length; ++i)
            if (games[i].current) return games[i]
        return null
    }

    // ---- covers ---------------------------------------------------------------------------------
    Flickable {
        id: flick
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: panel.left
        contentHeight: body.implicitHeight + 56
        clip: true
        Column {
            id: body
            x: 36; y: 28; width: flick.width - 60; spacing: 18

            Row {
                spacing: 12
                Text { id: heading; text: Theme.tr("library_title"); color: Theme.title; font.family: Theme.fontDisplay
                       font.variableAxes: ({ "wght": 800 }); font.pixelSize: 44; font.weight: Font.ExtraBold }
                Text { text: Backend.library.length; color: Theme.textMuted; font.family: Theme.fontText; font.pixelSize: 16
                       anchors.baseline: heading.baseline }
            }
            Text { width: Math.min(parent.width, 640); text: Theme.tr("library_hint"); wrapMode: Text.WordWrap; color: Theme.textMuted
                   font.family: Theme.fontText; font.pixelSize: 13; lineHeight: 1.35; lineHeightMode: Text.ProportionalHeight }

            Flow {
                width: parent.width; spacing: 20
                Repeater {
                    model: Backend.library
                    Item {
                        id: card
                        width: page.tileW; height: page.tileH + 34
                        readonly property bool hot: mouse.containsMouse
                        readonly property string image: modelData.art !== "" ? modelData.art : modelData.cover
                        MouseArea {   // under the cover so its remove button gets its own clicks
                            id: mouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Backend.selectGame(modelData.path)
                        }
                        Rectangle {   // the chosen game: an accent ring around its cover
                            visible: modelData.current
                            x: -6; y: -6; width: page.tileW + 12; height: page.tileH + 12; radius: 20
                            color: "transparent"; border.width: 3; border.color: page.accent
                        }
                        Rectangle {
                            id: cover
                            width: page.tileW; height: page.tileH; radius: 14; clip: true
                            color: page.placeholders[index % page.placeholders.length]
                            scale: card.hot && !modelData.current ? 1.03 : 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            Image {
                                anchors.fill: parent
                                source: card.image; visible: card.image !== ""
                                fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true
                            }
                            Text {   // no art in the dump: the title, poster style
                                visible: card.image === ""
                                x: 16; width: parent.width - 32; anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                                text: modelData.title.replace(/^inFAMOUS /, ""); wrapMode: Text.WordWrap; color: "#ffffff"
                                font.family: Theme.fontDisplay; font.variableAxes: ({ "wght": 800 }); font.pixelSize: 18
                                font.weight: Font.ExtraBold; font.capitalization: Font.AllUppercase; lineHeight: 0.95
                                lineHeightMode: Text.ProportionalHeight
                            }
                            Rectangle {   // state badge
                                visible: !modelData.present || !modelData.known
                                x: 10; y: 10; radius: 6; height: 24; width: badge.implicitWidth + 16
                                color: !modelData.present ? Theme.bad : Theme.warn
                                Text { id: badge; anchors.centerIn: parent; color: Theme.onAccent
                                       text: !modelData.present ? Theme.tr("library_missing") : Theme.tr("library_untested")
                                       font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Bold }
                            }
                            Rectangle {   // remove from the library (the folder itself is never touched)
                                visible: card.hot
                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                                width: 28; height: 28; radius: 14; color: Qt.rgba(0, 0, 0, 0.7)
                                Text { anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.pixelSize: 13 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; z: 2
                                            onClicked: Backend.removeGame(modelData.path) }
                                Accessible.role: Accessible.Button
                                Accessible.name: Theme.tr("library_remove")
                            }
                        }
                        Text {
                            anchors.top: cover.bottom; anchors.topMargin: 10
                            width: parent.width; text: modelData.title; elide: Text.ElideRight
                            color: modelData.current ? Theme.title : Theme.textSoft
                            font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Bold
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title
                    }
                }
                Item {   // add a game
                    width: page.tileW; height: page.tileH + 34
                    Rectangle {
                        width: page.tileW; height: page.tileH; radius: 14
                        color: addMouse.containsMouse ? Theme.ghostHover : "transparent"
                        border.width: 2; border.color: addMouse.containsMouse ? page.accent : Theme.ghostLine
                        Text { anchors.centerIn: parent; text: "+"; color: addMouse.containsMouse ? page.accent : Theme.textMuted
                               font.family: Theme.fontText; font.pixelSize: 48; font.weight: Font.Light }
                        MouseArea { id: addMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: addDialog.open() }
                        Accessible.role: Accessible.Button
                        Accessible.name: Theme.tr("library_add")
                    }
                    Text { y: page.tileH + 10; width: parent.width; text: Theme.tr("library_add_short"); elide: Text.ElideRight
                           color: Theme.textSoft; font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Bold }
                }
            }

            Row {   // Windows with Steam installed: one non-Steam shortcut per game
                visible: Backend.steamAvailable
                width: parent.width; spacing: 16
                GhostButton {
                    id: steamButton
                    text: Theme.tr(Backend.steamMustClose ? "steam_add_close" : "steam_add")
                    accent: page.accent
                    onClicked: Backend.addToSteam(Backend.steamMustClose)
                }
                Text { width: parent.width - steamButton.width - 16; anchors.verticalCenter: parent.verticalCenter
                       text: Theme.tr("steam_hint"); wrapMode: Text.WordWrap; color: Theme.textDim
                       font.family: Theme.fontText; font.pixelSize: 13 }
            }

            Text {   // folder accepted / rejected, Steam results
                visible: Backend.notice !== ""
                width: parent.width; wrapMode: Text.WordWrap; text: Backend.notice; color: Theme.textDim
                font.family: Theme.fontText; font.pixelSize: 13
            }

            Text {
                text: (Backend.version ? Backend.version + " · " : "") + Theme.tr("footer_license")
                color: Theme.textFaint; font.family: Theme.fontText; font.pixelSize: 12
            }
            Text {
                text: "☕  " + Theme.tr("support_project") + " →"; color: page.accent
                font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Bold
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Backend.openUrl("kofi") }
                Accessible.role: Accessible.Link
                Accessible.name: Theme.tr("support_project")
            }
        }
    }

    // ---- the chosen game ------------------------------------------------------------------------
    Rectangle {
        id: panel
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.margins: 24
        width: 330; radius: 22; color: Theme.card

        Item {   // above Play; a long note clips here instead of running under the button
            x: 28; y: 28; width: parent.width - 56; height: playCol.y - 44; clip: true
        Column {
            id: info
            width: parent.width; spacing: 12

            Text { visible: page.game !== null; width: parent.width; elide: Text.ElideRight; color: Theme.textMuted
                   text: page.game ? [page.game.title_id, page.game.version ? "v" + page.game.version : ""].filter(Boolean).join(" · ") : ""
                   font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Bold }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: Theme.title
                   text: page.game ? page.game.title : Theme.tr("lib_empty")
                   font.family: Theme.fontDisplay; font.variableAxes: ({ "wght": 800 })
                   font.pixelSize: page.game ? 23 : 18; font.weight: Font.ExtraBold; lineHeight: 1.05; lineHeightMode: Text.ProportionalHeight }

            Grid {
                visible: page.game !== null
                columns: 2; columnSpacing: 16; rowSpacing: 10; width: parent.width
                Repeater {
                    model: page.game ? [
                        { k: "lib_fact_tested", v: Theme.tr(page.game.known ? "rep_yes" : "rep_no") },
                        { k: "lib_fact_sensor", v: page.game.motion ? "L3 + R3" : Theme.tr("lib_sensor_off") } ] : []
                    Column {
                        width: (info.width - 16) / 2; spacing: 2
                        Text { text: Theme.tr(modelData.k); color: Theme.textMuted; font.family: Theme.fontText; font.pixelSize: 13 }
                        Text { text: modelData.v; color: Theme.title; font.family: Theme.fontText; font.pixelSize: 15; font.weight: Font.Bold }
                    }
                }
            }
            Text { visible: page.game !== null && page.game.note !== ""; width: parent.width; wrapMode: Text.WordWrap
                   text: page.game ? page.game.note : ""; color: Theme.textSoft
                   font.family: Theme.fontText; font.pixelSize: 13; lineHeight: 1.3; lineHeightMode: Text.ProportionalHeight }

            Column {   // what the launcher checked: folder, GPU, profile, shader cache, controller
                visible: page.game !== null
                width: parent.width; spacing: 6
                Repeater {
                    model: Backend.chips
                    Row {
                        spacing: 10; width: info.width
                        Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter
                                    color: modelData.level === "ok" ? Theme.ok : modelData.level === "warn" ? Theme.warn
                                         : modelData.level === "bad" ? Theme.bad : Theme.off }
                        Text { width: info.width - 18; text: modelData.text; elide: Text.ElideRight; color: Theme.textSoft
                               font.family: Theme.fontText; font.pixelSize: 13 }
                    }
                }
            }

            Row {   // game language (voice and text): next start; the interface language is in the top bar
                visible: page.game !== null
                spacing: 10
                Text { text: Theme.tr("game_language_label"); color: Theme.textMuted; font.family: Theme.fontText; font.pixelSize: 12
                       font.weight: Font.Bold; width: 70; wrapMode: Text.WordWrap; anchors.verticalCenter: parent.verticalCenter }
                Select {
                    accent: page.accent; width: info.width - 80
                    model: Backend.gameLanguageOptions
                    currentIndex: Backend.gameLanguageIndex
                    onActivated: (i) => Backend.setGameLanguage(Backend.gameLanguageOptions[i].value)
                }
            }
        }

        }

        Column {
            id: playCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 24; spacing: 8
            Rectangle {
                id: playBtn
                width: parent.width; height: 64; radius: 16
                color: !Backend.canPlay ? Theme.disabledFill : (playMouse.containsMouse ? Qt.lighter(page.accent, 1.1) : page.accent)
                Row {
                    anchors.centerIn: parent; spacing: 14
                    Icon { path: Theme.icons.play; color: Backend.canPlay ? Theme.onAccent : Theme.disabledText; size: 22
                           anchors.verticalCenter: parent.verticalCenter }
                    Text { text: Theme.tr("play_label"); color: Backend.canPlay ? Theme.onAccent : Theme.disabledText
                           font.family: Theme.fontDisplay; font.variableAxes: ({ "wght": 800 }); font.pixelSize: 22; font.weight: Font.ExtraBold
                           anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle {   // shader list progress (first start): thin bar along the button's bottom edge
                    visible: Backend.jobsProgressValue >= 0
                    x: 20; width: playBtn.width - 40; height: 4; radius: 2
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                    color: Qt.rgba(1, 1, 1, 0.35)
                    Rectangle { width: parent.width * Math.max(0, Backend.jobsProgressValue); height: parent.height
                                radius: 2; color: Theme.onAccent }
                }
                MouseArea { id: playMouse; anchors.fill: parent; hoverEnabled: true
                            enabled: Backend.canPlay; cursorShape: Qt.PointingHandCursor; onClicked: Backend.play() }
                Accessible.role: Accessible.Button
                Accessible.name: Theme.tr("play_label")
            }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                   text: Backend.playSubtitle; color: Theme.textMuted; font.family: Theme.fontText; font.pixelSize: 12 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Theme.tr("nav_game_log") + " →"; color: page.accent
                   font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Bold
                   MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.openLog() } }
        }
    }

    FolderDialog {
        id: addDialog
        title: Theme.tr("choose_folder_title")
        onAccepted: Backend.addGame(selectedFolder.toString())
    }
}
