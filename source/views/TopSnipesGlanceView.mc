import Toybox.Graphics;
import Toybox.WatchUi;

class TopSnipesGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var centerX = width / 2;

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.clear();

        dc.drawText(centerX, 8, Graphics.FONT_SMALL, Rez.Strings.GlanceTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var line = Rez.Strings.GlanceNoSession;
        var storage = AppContext.storageManager();
        var sync = AppContext.syncManager();
        var pending = 0;
        if (sync != null) {
            pending = sync.pendingCount();
        }
        if (storage != null) {
            var lastTotal = storage.lastSessionTotalMs();
            if (lastTotal != null) {
                line = FormatUtils.formatMillis(lastTotal) + " | " + pending.toString() + " " + Rez.Strings.GlancePending;
            }
        }
        line = trimText(line, 24);

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(centerX, 30, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_CENTER);
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
