/* Forge installer slideshow — shown during install */
import QtQuick 2.15

Rectangle {
    color: "#1e1e2e"
    anchors.fill: parent

    Column {
        anchors.centerIn: parent
        spacing: 16

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Installing Forge 43"
            color: "#cdd6f4"
            font.pixelSize: 28
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Pulling image from registry — this may take a while."
            color: "#a6adc8"
            font.pixelSize: 16
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Do not power off your computer."
            color: "#a6adc8"
            font.pixelSize: 14
        }
    }
}
