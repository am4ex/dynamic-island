import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: root

    property real bodyWidth: 0
    property real bodyHeight: 0
    property real radius: 10
    property var levels: []
    property real waveAmount: 0
    property real phase: 0
    property real drip: 0
    property real dripWidth: 40
    property real dripX: bodyWidth / 2
    property real gradient: 0
    property real pull: 0
    property real pullX: 0
    property color fillColor: Theme.background
    property color edgeColor: Theme.accent
    property real glow: 0

    readonly property real maxWave: 14
    readonly property real toothPeriod: 22

    width: bodyWidth
    height: bodyHeight + 40

    function levelAt(t) {
        const l = levels;
        const n = l ? l.length : 0;
        if (n === 0)
            return 0.45 + 0.25 * Math.sin(phase * 3 + t * 9);
        const f = Math.max(0, Math.min(n - 1, t * (n - 1)));
        const i = Math.floor(f);
        const j = Math.min(n - 1, i + 1);
        return l[i] + (l[j] - l[i]) * (f - i);
    }

    function offsetAt(x, w, r) {
        if (w <= 0)
            return 0;
        const t = Math.max(0, Math.min(1, x / w));
        const ramp = 10;
        const a = Math.max(0, Math.min(1, (x - 2) / ramp));
        const b = Math.max(0, Math.min(1, (w - 2 - x) / ramp));
        const env = a * a * (3 - 2 * a) * b * b * (3 - 2 * b);
        let y = 0;
        if (waveAmount > 0.001) {
            const tooth = 1 - Math.abs(Math.sin(Math.PI * x / toothPeriod + phase * 0.6));
            y += waveAmount * maxWave * (0.12 + 0.88 * levelAt(t)) * tooth * env;
        }
        if (Math.abs(drip) > 0.001) {
            const d = (x - dripX) / dripWidth;
            y += drip * Math.exp(-d * d);
        }
        if (Math.abs(pull) > 0.001) {
            const p = (x - pullX) / Math.max(30, w * 0.24);
            y += pull * Math.exp(-p * p) * env;
        }
        return y;
    }

    readonly property var edge: {
        const w = bodyWidth;
        const h = bodyHeight;
        const r = Math.max(0, Math.min(radius, w / 2, h / 2));
        const pts = [];
        const seg = 10;
        for (let k = 0; k <= seg; k++) {
            const a = 0.5 * Math.PI * k / seg;
            const x = w - r + r * Math.cos(a);
            const s = Math.sin(a);
            pts.push(Qt.point(x, h - r + r * s + offsetAt(x, w, r) * s * s));
        }
        for (let x = w - r - 3; x > r; x -= 3)
            pts.push(Qt.point(x, h + offsetAt(x, w, r)));
        for (let k = 0; k <= seg; k++) {
            const a = 0.5 * Math.PI + 0.5 * Math.PI * k / seg;
            const x = r + r * Math.cos(a);
            const s = Math.sin(a);
            pts.push(Qt.point(x, h - r + r * s + offsetAt(x, w, r) * s * s));
        }
        return pts;
    }

    readonly property var outline: {
        const w = bodyWidth;
        const h = bodyHeight;
        const r = Math.max(0, Math.min(radius, w / 2, h / 2));
        const pts = [];
        const seg = 10;
        const arc = (cx, cy, a0, a1) => {
            for (let k = 0; k <= seg; k++) {
                const a = a0 + (a1 - a0) * k / seg;
                pts.push(Qt.point(cx + r * Math.cos(a), cy + r * Math.sin(a)));
            }
        };
        arc(r, r, Math.PI, 1.5 * Math.PI);
        arc(w - r, r, 1.5 * Math.PI, 2 * Math.PI);
        const e = edge;
        for (let i = 0; i < e.length; i++)
            pts.push(e[i]);
        pts.push(pts[0]);
        return pts;
    }

    readonly property real fadeEnd: Math.min(0.3, (radius * 1.4) / Math.max(1, bodyWidth))

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer

        layer.enabled: true
        layer.samples: 4
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#90000000"
            shadowBlur: 0.6
            shadowVerticalOffset: 3
            blurMax: 20
        }

        ShapePath {
            strokeColor: "transparent"
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.bodyHeight + root.maxWave
                GradientStop { position: 0; color: root.fillColor }
                GradientStop {
                    position: Math.max(0, Math.min(0.99, (root.bodyHeight - 80) / (root.bodyHeight + root.maxWave)))
                    color: root.fillColor
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(root.fillColor.r + (root.edgeColor.r * 0.55 - root.fillColor.r) * root.gradient, root.fillColor.g + (root.edgeColor.g * 0.55 - root.fillColor.g) * root.gradient, root.fillColor.b + (root.edgeColor.b * 0.55 - root.fillColor.b) * root.gradient, 1)
                }
            }
            PathPolyline { path: root.outline }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.glow > 0.01
        preferredRendererType: Shape.GeometryRenderer
        layer.enabled: visible
        layer.samples: 4

        ShapePath {
            fillColor: "transparent"
            strokeWidth: 5
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            strokeGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: root.bodyWidth
                y2: 0
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: root.fadeEnd; color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, root.glow) }
                GradientStop { position: 1 - root.fadeEnd; color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, root.glow) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathPolyline { path: root.edge }
        }

        ShapePath {
            fillColor: "transparent"
            strokeWidth: 2.8
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            strokeGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: root.bodyWidth
                y2: 0
                GradientStop { position: 0; color: Qt.rgba(root.edgeColor.r, root.edgeColor.g, root.edgeColor.b, 0) }
                GradientStop { position: root.fadeEnd; color: Qt.rgba(root.edgeColor.r, root.edgeColor.g, root.edgeColor.b, root.glow) }
                GradientStop { position: 1 - root.fadeEnd; color: Qt.rgba(root.edgeColor.r, root.edgeColor.g, root.edgeColor.b, root.glow) }
                GradientStop { position: 1; color: Qt.rgba(root.edgeColor.r, root.edgeColor.g, root.edgeColor.b, 0) }
            }
            PathPolyline { path: root.edge }
        }
    }
}
