import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

class HistoryView extends WatchUi.View {
    var _sessions as Array<SessionData>;
    var _selected as Number;
    var _offset as Number;

    function initialize() {
        View.initialize();
        _sessions = [];
        _selected = 0;
        _offset = 0;
    }

    function onShow() as Void {
        reload();
    }

    function reload() as Void {
        var storage = AppContext.storageManager();
        if (storage == null) {
            _sessions = [];
            return;
        }

        _sessions = storage.recentSessions(40);
        if (_selected >= _sessions.size()) {
            _selected = _sessions.size() - 1;
        }
        if (_selected < 0) {
            _selected = 0;
        }
    }

    function move(delta as Number) as Void {
        if (_sessions.size() == 0) {
            return;
        }

        _selected += delta;
        if (_selected < 0) {
            _selected = 0;
        }
        if (_selected >= _sessions.size()) {
            _selected = _sessions.size() - 1;
        }

        if (_selected < _offset) {
            _offset = _selected;
        }
        if (_selected >= (_offset + 5)) {
            _offset = _selected - 4;
        }

        WatchUi.requestUpdate();
    }

    function selectedSession() as SessionData or Null {
        if (_sessions.size() == 0) {
            return null;
        }
        return _sessions[_selected];
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var centerX = dc.getWidth() / 2;

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.clear();

        dc.drawText(centerX, 10, Graphics.FONT_SMALL, Rez.Strings.HistoryTitle, Graphics.TEXT_JUSTIFY_CENTER);

        if (_sessions.size() == 0) {
            dc.drawText(centerX, dc.getHeight() / 2, Graphics.FONT_TINY, Rez.Strings.HistoryEmpty, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var rowY = 34;
        for (var i = _offset; i < _sessions.size(); i += 1) {
            if (i >= _offset + 5) {
                break;
            }

            var session = _sessions[i];
            if (i == _selected) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Constants.COLOR_BG);
                dc.fillRoundedRectangle(12, rowY - 2, dc.getWidth() - 24, 22, 5);
                dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
            }

            var left = Constants.weaponLabel(session.weaponType);
            var right = FormatUtils.formatMillis(session.totalTimeMs);
            dc.drawText(20, rowY + 1, Graphics.FONT_XTINY, left, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(dc.getWidth() - 20, rowY + 1, Graphics.FONT_XTINY, right, Graphics.TEXT_JUSTIFY_RIGHT);
            rowY += 24;
        }

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(centerX, dc.getHeight() - 16, Graphics.FONT_XTINY, Rez.Strings.HistoryHint, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
