/* Kyth installer slideshow — shown during the exec (installation) phase. */

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    anchors.fill: parent

    Column {
        anchors.centerIn: parent
        spacing: 24

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Installing Kyth"
            font.pixelSize: 28
            font.bold: true
            color: "#c0caf5"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Downloading and writing the OS image.\nThis may take 10–30 minutes depending on your internet connection."
            font.pixelSize: 14
            color: "#9aa5ce"
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Kyth is a gaming and development desktop\nbuilt on Fedora Kinoite with the CachyOS kernel."
            font.pixelSize: 13
            color: "#565f89"
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
