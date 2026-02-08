import Toybox.Graphics;
import Toybox.WatchUi;

class ReviewView extends WatchUi.View {
    var _session as SessionData;
    var _offset as Number;

    function initialize(session as SessionData) {
        View.initialize();
        _session = session;
        _offset = 0;
    }

    function session() as SessionData {
        return _session;
    }

    function scroll(delta as Number) as Void {
        var splitCount = _session.splitTimes.size();
        if (splitCount <= Constants.MAX_SPLITS_TO_DRAW) {
            _offset = 0;
            return;
        }

        _offset += delta;
        if (_offset < 0) {
            _offset = 0;
        }

        var maxOffset = splitCount - Constants.MAX_SPLITS_TO_DRAW;
        if (_offset > maxOffset) {
            _offset = maxOffset;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var centerX = width / 2;

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.clear();

        dc.drawText(centerX, 8, Graphics.FONT_SMALL, Rez.Strings.ReviewTitle, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 24, Graphics.FONT_XTINY, Constants.weaponLabel(_session.weaponType) + " • " + Constants.drillLabel(_session.drillType), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Constants.COLOR_ACCENT, Constants.COLOR_BG);
        dc.drawText(centerX, 44, Graphics.FONT_MEDIUM, FormatUtils.formatMillis(_session.totalTimeMs), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(centerX, 60, Graphics.FONT_XTINY, FormatUtils.formatShotCount(_session.shotCount), Graphics.TEXT_JUSTIFY_CENTER);
        var avgSplit = _session.averageSplit();
        if (avgSplit == null) {
            dc.drawText(centerX, 74, Graphics.FONT_XTINY, Rez.Strings.ReviewAvgSplit + ": --", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(centerX, 74, Graphics.FONT_XTINY, Rez.Strings.ReviewAvgSplit + ": " + FormatUtils.formatMillis(avgSplit), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.drawText(20, 92, Graphics.FONT_XTINY, Rez.Strings.ReviewSplitHeader, Graphics.TEXT_JUSTIFY_LEFT);

        var rowY = 108;
        var rendered = 0;
        for (var i = _offset; i < _session.splitTimes.size(); i += 1) {
            if (rendered >= Constants.MAX_SPLITS_TO_DRAW) {
                break;
            }

            var label = "#" + (i + 2).toString();
            var splitStr = FormatUtils.formatMillis(_session.splitTimes[i]);
            dc.drawText(26, rowY, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(width - 26, rowY, Graphics.FONT_XTINY, splitStr, Graphics.TEXT_JUSTIFY_RIGHT);
            rowY += 16;
            rendered += 1;
        }

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(centerX, dc.getHeight() - 14, Graphics.FONT_XTINY, Rez.Strings.ReviewHintCompact, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
