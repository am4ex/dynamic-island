import QtQuick
import QtQuick.Effects

Item {
    id: root

    property bool shown: false
    default property alias content: inner.data

    opacity: shown ? 1 : 0
    visible: opacity > 0.001

    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Item {
        id: inner
        anchors.fill: parent
        scale: 0.92 + 0.08 * root.opacity

        layer.enabled: root.opacity > 0.001 && root.opacity < 0.999
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 24
            blur: 1 - root.opacity
        }
    }
}
