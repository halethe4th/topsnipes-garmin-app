import Toybox.Graphics;
import Toybox.Timer;
import Toybox.WatchUi;

class SyncStatusView extends WatchUi.View {
    var _timer as Timer.Timer;

    function initialize() {
        View.initialize();
        _timer = new Timer.Timer();
    }

    function onShow() as Void {
        var sync = AppContext.syncManager();
        if (sync != null) {
            sync.checkPendingSyncs();
        }
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() as Void {
        _timer.stop();
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var centerX = dc.getWidth() / 2;
        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.clear();

        dc.drawText(centerX, 20, Graphics.FONT_SMALL, Rez.Strings.SyncTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var status = Rez.Strings.SyncUnavailable;
        var pending = 0;

        var sync = AppContext.syncManager();
        if (sync != null) {
            status = sync.statusText();
            pending = sync.pendingCount();
        }
        status = trimText(status, 24);

        dc.drawText(centerX, 58, Graphics.FONT_MEDIUM, pending.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 78, Graphics.FONT_XTINY, Rez.Strings.SyncPendingLabel, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(centerX, 110, Graphics.FONT_TINY, status, Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(centerX, dc.getHeight() - 16, Graphics.FONT_XTINY, Rez.Strings.SyncHint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function trimText(value as String, maxChars as Number) as String {
        if (value.length() <= maxChars) {
            return value;
        }
        if (maxChars <= 3) {
            return value.substring(0, maxChars);
        }
        return value.substring(0, maxChars - 3) + "...";
    }
}
