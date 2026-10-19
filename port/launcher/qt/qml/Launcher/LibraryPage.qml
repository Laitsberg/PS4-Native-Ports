import QtQuick
import QtQuick.Dialogs
import Launcher

// The game library: one tile per game folder the player added (cover and name from the dump's own
// sce_sys/icon0.png and param.sfo). Clicking a tile makes it the game Play starts.
Item {
    id: page
    signal openPlay()
    readonly property color accent: Theme.accents.library
    readonly property int tile: 196

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: body.implicitHeight + 72
        clip: true
        Column {
            id: body
            x: 36; y: 34; width: flick.width - 72; spacing: 18

            Column {
                width: parent.width; spacing: 6
                Text { text: Theme.tr("brand"); color: page.accent; font.family: Theme.fontDisplay; font.variableAxes: ({ "wght": 700 })
                       font.pixelSize: 15; font.weight: Font.Bold; font.capitalization: Font.AllUppercase; font.letterSpacing: 4.5 }
                Text { text: Theme.tr("library_title"); color: "#fff"; font.family: Theme.fontDisplay; font.variableAxes: ({ "wght": 800 })
                       font.pixelSize: 52; font.weight: Font.ExtraBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 2.4 }
                Text { width: Math.min(parent.width, 720); text: Theme.tr("library_hint"); wrapMode: Text.WordWrap; color: Theme.textSoft
                       font.family: Theme.fontText; font.pixelSize: 14; lineHeight: 1.35; lineHeightMode: Text.ProportionalHeight }
            }

            Flow {
                width: parent.width; spacing: 18
                Repeater {
                    model: Backend.library
                    Item {
                        id: card
                        width: page.tile; height: page.tile + 74
                        readonly property bool hot: mouse.containsMouse
                        MouseArea {   // under the cover so its remove button gets its own clicks
                            id: mouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { Backend.selectGame(modelData.path); page.openPlay() }
                        }
                        Rectangle {   // cover
                            id: cover
                            width: page.tile; height: page.tile; radius: 14; clip: true
                            color: Theme.card
                            border.width: modelData.current ? 3 : 1
                            border.color: modelData.current ? page.accent : (card.hot ? Theme.ghostLineHover : Theme.cardLine)
                            scale: card.hot ? 1.03 : 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            Image {
                                anchors.fill: parent; anchors.margins: parent.border.width
                                source: modelData.cover; visible: modelData.cover !== ""
                                fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true
                            }
                            Text {   // no icon0.png in the dump: the title on a plain card
                                visible: modelData.cover === ""
                                anchors.centerIn: parent; width: parent.width - 28
                                text: modelData.title; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                                color: Theme.text; font.family: Theme.fontDisplay; font.pixelSize: 22; font.weight: Font.Bold
                            }
                            Rectangle {   // state badge
                                visible: modelData.current || !modelData.present || !modelData.known
                                x: 10; y: 10; radius: 6; height: 24; width: badge.implicitWidth + 16
                                color: !modelData.present ? Theme.bad : modelData.current ? page.accent : Theme.warn
                                Text { id: badge; anchors.centerIn: parent; color: "#120c08"
                                       text: !modelData.present ? Theme.tr("library_missing")
                                             : modelData.current ? Theme.tr("library_selected") : Theme.tr("library_untested")
                                       font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Bold }
                            }
                            Rectangle {   // remove from the library (the folder itself is never touched)
                                visible: card.hot
                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                                width: 28; height: 28; radius: 14; color: Qt.rgba(0, 0, 0, 0.7)
                                border.width: 1; border.color: Theme.ghostLine
                                Text { anchors.centerIn: parent; text: "✕"; color: Theme.text; font.pixelSize: 13 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; z: 2
                                            onClicked: Backend.removeGame(modelData.path) }
                                Accessible.role: Accessible.Button
                                Accessible.name: Theme.tr("library_remove")
                            }
                        }
                        Column {
                            anchors.top: cover.bottom; anchors.topMargin: 10
                            width: parent.width; spacing: 2
                            Text { width: parent.width; text: modelData.title; elide: Text.ElideRight; color: modelData.current ? "#fff" : Theme.text
                                   font.family: Theme.fontText; font.pixelSize: 15; font.weight: Font.Bold }
                            Text { width: parent.width; elide: Text.ElideRight; color: Theme.textDim
                                   text: [modelData.title_id, modelData.version ? "v" + modelData.version : ""].filter(Boolean).join(" · ")
                                   font.family: Theme.fontText; font.pixelSize: 12 }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title
                    }
                }
                Item {   // add a game
                    width: page.tile; height: page.tile + 74
                    Rectangle {
                        width: page.tile; height: page.tile; radius: 14
                        color: addMouse.containsMouse ? Theme.ghostHover : "transparent"
                        border.width: 2; border.color: addMouse.containsMouse ? page.accent : Theme.ghostLine
                        Column {
                            anchors.centerIn: parent; spacing: 10
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "+"; color: page.accent
                                   font.family: Theme.fontDisplay; font.pixelSize: 56; font.weight: Font.Bold }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; width: page.tile - 32
                                   horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                                   text: Theme.tr("library_add"); color: Theme.textSoft
                                   font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Bold }
                        }
                        MouseArea { id: addMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: addDialog.open() }
                        Accessible.role: Accessible.Button
                        Accessible.name: Theme.tr("library_add")
                    }
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

            Text {   // folder accepted / rejected (same messages as the Play screen)
                visible: Backend.notice !== ""
                width: parent.width; wrapMode: Text.WordWrap; text: Backend.notice; color: Theme.textDim
                font.family: Theme.fontText; font.pixelSize: 13
            }
        }
    }

    FolderDialog {
        id: addDialog
        title: Theme.tr("choose_folder_title")
        onAccepted: { Backend.addGame(selectedFolder.toString()); page.openPlay() }
    }
}
