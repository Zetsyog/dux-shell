pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets

Item {
    id: root

    property bool vertical: false
    property bool live: visible && enabled
    property string displayMode: "both"
    property bool dateFirst: false
    property real fontSize: Theme.fontSizeMedium
    property real availableWidth: fontSize * 2
    property color textColor: Theme.surfaceText
    property color dateColor: textColor
    property color separatorColor: Theme.outlineButton
    property color outlineColor: Theme.hostSurface
    property real outlineWidth: 3
    property bool segmented: false
    property var locale: I18n.locale()
    property date date: systemClock.date

    readonly property bool funStyle: displayMode === "fun"
    readonly property real colonOffset: Math.round(digitMetrics.tightBoundingRect.y + digitMetrics.tightBoundingRect.height / 2 - colonMetrics.tightBoundingRect.y - colonMetrics.tightBoundingRect.height / 2)
    readonly property string timeText: date.toLocaleTimeString(locale, funStyle ? SettingsData.getEffectiveTimeFormat().replace(/^h:/, "hh:") : SettingsData.getEffectiveTimeFormat())
    readonly property string dateText: date.toLocaleDateString(locale, SettingsData.getEffectiveDateFormat())
    readonly property var timeLines: vertical ? stackedTime() : [timeText]
    readonly property var dateLines: vertical ? stackedDate() : [dateText]
    readonly property bool showTime: displayMode !== "date"
    readonly property bool showDate: displayMode !== "time" && !funStyle
    readonly property bool split: segmented && !vertical && showTime && showDate
    readonly property real splitOffset: split ? layout.x + separator.x + separator.width / 2 : 0

    implicitWidth: vertical ? availableWidth : layout.implicitWidth
    implicitHeight: layout.implicitHeight

    function pad(value) {
        return String(value).padStart(2, "0");
    }

    function stackedTime() {
        const hours = date.getHours();
        const lines = [pad(SettingsData.use24HourClock ? hours : (hours % 12 || 12)), pad(date.getMinutes())];
        if (SettingsData.showSeconds)
            lines.push(pad(date.getSeconds()));
        if (!SettingsData.use24HourClock && SettingsData.showAmPm)
            lines.push(hours >= 12 ? locale.pmText : locale.amText);
        return lines;
    }

    function stackedDate() {
        const format = locale.dateFormat(Locale.ShortFormat);
        const day = pad(date.getDate());
        const month = pad(date.getMonth() + 1);
        return format.indexOf("d") < format.indexOf("M") ? [day, month] : [month, day];
    }

    component StackedLines: Column {
        id: stack

        property var lines: []
        property color color: root.textColor

        width: root.vertical ? root.availableWidth : implicitWidth

        Repeater {
            model: stack.lines.length

            Row {
                id: line

                required property int index
                readonly property string text: stack.lines[index] ?? ""
                readonly property var cells: root.vertical || root.funStyle ? (text.match(/\d|\D+/g) || []) : [text]

                anchors.horizontalCenter: parent.horizontalCenter
                LayoutMirroring.enabled: false

                Repeater {
                    model: line.cells.length

                    Item {
                        id: cell

                        required property int index
                        readonly property bool tighten: root.funStyle && (root.vertical ? line.index < 2 && index === 0 : index === 0 || index === 3)

                        width: glyph.width - (tighten ? Theme.spacingXXS * 4 : 0)
                        height: glyph.height

                        NumericText {
                            id: glyph

                            text: line.cells[cell.index] ?? ""
                            y: root.funStyle && text === ":" ? root.colonOffset : 0
                            color: root.funStyle && (root.vertical ? line.index < 2 && cell.index === 1 : cell.index === 1 || cell.index === 4) ? Theme.primary : stack.color
                            fontToken: root.funStyle ? (titanOneFont.name || "Titan One") : "ui"
                            font.pixelSize: root.fontSize

                            Repeater {
                                model: root.funStyle && root.outlineWidth > 0 ? 8 : 0

                                StyledText {
                                    required property int index

                                    x: Math.cos(index * Math.PI / 4) * root.outlineWidth
                                    y: Math.sin(index * Math.PI / 4) * root.outlineWidth
                                    z: -1
                                    width: glyph.width
                                    height: glyph.height
                                    text: glyph.text
                                    font: glyph.font
                                    color: root.outlineColor
                                    renderType: glyph.renderType
                                    renderTypeQuality: glyph.renderTypeQuality
                                    horizontalAlignment: glyph.horizontalAlignment
                                    wrapMode: Text.NoWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Grid {
        id: layout

        anchors.centerIn: parent
        columns: root.vertical ? 1 : Math.max(1, layout.visibleChildren.length)
        spacing: root.vertical ? 0 : Theme.spacingS
        verticalItemAlignment: Grid.AlignVCenter

        Loader {
            sourceComponent: root.dateFirst && root.showDate || !root.showTime ? dateComponent : timeComponent
        }

        Item {
            id: separator
            visible: root.showTime && root.showDate
            width: root.vertical ? root.availableWidth : (root.split ? Theme.groupedListGap : dot.implicitWidth)
            height: root.vertical ? Theme.spacingM : root.fontSize

            Rectangle {
                visible: root.vertical
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: 1
                color: root.separatorColor
            }

            StyledText {
                id: dot
                visible: !root.vertical && !root.split
                anchors.centerIn: parent
                text: "•"
                color: root.separatorColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Loader {
            active: root.showTime && root.showDate
            visible: active
            sourceComponent: root.dateFirst ? timeComponent : dateComponent
        }
    }

    Component {
        id: timeComponent

        StackedLines {
            lines: root.timeLines
        }
    }

    Component {
        id: dateComponent

        StackedLines {
            lines: root.dateLines
            color: root.dateColor
        }
    }

    StyledTextMetrics {
        id: digitMetrics

        text: "0"
        fontToken: titanOneFont.name || "Titan One"
        font.pixelSize: root.fontSize
    }

    StyledTextMetrics {
        id: colonMetrics

        text: ":"
        font: digitMetrics.font
    }

    FontLoader {
        id: titanOneFont
        source: root.funStyle ? Qt.resolvedUrl("../assets/fonts/titan-one/TitanOne-Regular.ttf") : ""
    }

    SystemClock {
        id: systemClock
        enabled: root.live
        precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Connections {
        target: SessionService
        function onSessionResumed() {
            systemClock.enabled = false;
            systemClock.enabled = Qt.binding(() => root.live);
        }
    }
}
