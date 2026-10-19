import QtQuick
import QtQuick.Controls.Basic
import Launcher

// The top bar: the brand, the main sections as tabs (the current one a light pill), the rest
// under "More", and the interface language.
Rectangle {
    id: root
    property int current: 0
    property var pages: []
    signal pick(int index)
    readonly property var tabs: ["library", "graphics", "controls", "fixes", "saves", "support"]
    // Controller guides open from the Controls screen; Mods (cheat files) are Second Son's.
    readonly property var more: ["play", "updates", "advanced"].concat(Backend.isSecondSon ? ["mods"] : [])
    readonly property var labels: ({ library: "nav_library", graphics: "nav_graphics", controls: "nav_controls", fixes: "nav_fixes",
                                     saves: "nav_saves_short", support: "nav_support", play: "nav_game_log", updates: "nav_updates",
                                     advanced: "nav_advanced", mods: "nav_mods" })
    readonly property bool moreCurrent: root.more.indexOf(root.pages[root.current]) >= 0 || root.pages[root.current] === "guides"
    height: 72
    color: Theme.bg
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.railLine }

    Text {
        id: brand
        x: 28; anchors.verticalCenter: parent.verticalCenter
        visible: root.width >= 1100   // a narrow window keeps the tabs and drops the name
        text: Theme.tr("brand"); color: Theme.title
        font.family: Theme.fontDisplay; font.variableAxes: ({ "wght": 800 }); font.pixelSize: 17; font.weight: Font.ExtraBold
    }

    Row {
        id: tabRow
        anchors.left: brand.visible ? brand.right : parent.left; anchors.leftMargin: brand.visible ? 18 : 20; anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
            model: root.tabs
            Rectangle {
                readonly property bool on: root.pages[root.current] === modelData
                height: 38; radius: 19; width: tabText.implicitWidth + 22
                color: on ? Theme.navOn : (tabMouse.containsMouse ? Theme.navHover : "transparent")
                Text { id: tabText; anchors.centerIn: parent; text: Theme.tr(root.labels[modelData])
                       color: parent.on ? Theme.onNav : Theme.textSoft
                       font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.DemiBold }
                MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.pick(root.pages.indexOf(modelData)) }
                Accessible.role: Accessible.PageTab
                Accessible.name: tabText.text
            }
        }
        Rectangle {   // the other sections
            height: 38; radius: 19; width: moreText.implicitWidth + 22
            color: root.moreCurrent ? Theme.navOn : (moreMouse.containsMouse || menu.visible ? Theme.navHover : "transparent")
            Text { id: moreText; anchors.centerIn: parent; text: Theme.tr("nav_more") + "  ▾"
                   color: root.moreCurrent ? Theme.onNav : Theme.textSoft
                   font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.DemiBold }
            Rectangle {   // a new release
                visible: Updates.available
                width: 8; height: 8; radius: 4; color: Theme.warn
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4
            }
            MouseArea { id: moreMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: menu.visible ? menu.close() : menu.open() }
            Accessible.role: Accessible.ButtonMenu
            Accessible.name: Theme.tr("nav_more")
            Popup {
                id: menu
                y: parent.height + 8; padding: 6
                background: Rectangle { radius: 12; color: Theme.card; border.width: 1; border.color: Theme.cardLine }
                contentItem: Column {
                    spacing: 2
                    Repeater {
                        model: root.more
                        Rectangle {
                            width: 220; height: 40; radius: 8
                            color: itemMouse.containsMouse ? Theme.navHover : "transparent"
                            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: Theme.tr(root.labels[modelData])
                                   color: root.pages[root.current] === modelData ? Theme.smoke : Theme.text
                                   font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Rectangle {
                                visible: modelData === "updates" && Updates.available
                                width: 8; height: 8; radius: 4; color: Theme.warn
                                anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                            }
                            MouseArea { id: itemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { menu.close(); root.pick(root.pages.indexOf(modelData)) } }
                            Accessible.role: Accessible.MenuItem
                            Accessible.name: Theme.tr(root.labels[modelData])
                        }
                    }
                }
            }
        }
    }

    Rectangle {   // interface language
        anchors.right: parent.right; anchors.rightMargin: 28; anchors.verticalCenter: parent.verticalCenter
        width: langRow.implicitWidth + 6; height: 38; radius: 19; color: Theme.card
        Row {
            id: langRow
            anchors.centerIn: parent; spacing: 2
            Repeater {
                model: [ { code: "pt_BR", label: "PT" }, { code: "en_US", label: "EN" }, { code: "ru_RU", label: "RU" } ]
                Rectangle {
                    readonly property bool on: Backend.lang === modelData.code
                    width: 42; height: 32; radius: 16
                    color: on ? Theme.navOn : "transparent"
                    Text { anchors.centerIn: parent; text: modelData.label; color: parent.on ? Theme.onNav : Theme.textMuted
                           font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Backend.setLang(modelData.code) }
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                }
            }
        }
    }
}
