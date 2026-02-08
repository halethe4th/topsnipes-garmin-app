import Toybox.Graphics;
import Toybox.Timer;
import Toybox.WatchUi;

class ActiveSessionView extends WatchUi.View {
    var _updateTimer as Timer.Timer;

    function initialize() {
        View.initialize();
        _updateTimer = new Timer.Timer();
    }

    function onShow() as Void {
        _updateTimer.start(method(:onTick), 100, true);
    }

    function onHide() as Void {
        _updateTimer.stop();
    }

    function onTick() as Void {
        var manager = AppContext.sessionManager();
        if (manager != null) {
            manager.updateState();
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var manager = AppContext.sessionManager();
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.clear();

        if (manager == null || manager.activeSession() == null) {
            dc.drawText(centerX, centerY, Graphics.FONT_MEDIUM, Rez.Strings.ActiveNoSession, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var session = manager.activeSession() as SessionData;
        var state = manager.state();
        var gpsStatus = trimText(manager.gpsStatusLabel(), 16);
        var gpsProgress = manager.gpsProgressPercent();
        var gpsColor = Constants.COLOR_WARNING;
        if (manager.gpsIsVerified()) {
            gpsColor = Constants.COLOR_ACCENT;
            gpsProgress = 100;
        }

        var statusText = Rez.Strings.StateReady;
        var statusColor = Constants.COLOR_SUBTLE;
        var primaryText = Rez.Strings.StateReady;
        var primaryFont = Graphics.FONT_LARGE;
        var detailLine1 = trimText(Constants.weaponLabel(session.weaponType), 18);
        var detailLine2 = Rez.Strings.ActiveSelected;

        if (state == Constants.SessionState.STATE_COUNTDOWN) {
            statusText = Rez.Strings.StateCountdown;
            statusColor = Constants.COLOR_WARNING;
            var countdownSecs = (manager.countdownRemainingMs() + 999) / 1000;
            primaryText = countdownSecs.toString();
            primaryFont = Graphics.FONT_NUMBER_THAI_HOT;
            detailLine1 = Rez.Strings.StateGetReady;
            detailLine2 = trimText(Constants.weaponLabel(session.weaponType), 18);
        } else if (state == Constants.SessionState.STATE_LISTENING) {
            statusText = Rez.Strings.StateListening;
            statusColor = Constants.COLOR_ACCENT;
            primaryText = FormatUtils.formatMillis(manager.elapsedMs());
            primaryFont = Graphics.FONT_NUMBER_THAI_HOT;
            detailLine1 = FormatUtils.formatShotCount(session.shotCount);
            var listeningSplit = session.lastSplit();
            if (listeningSplit == null) {
                detailLine2 = Rez.Strings.ActiveLastSplit + ": --";
            } else {
                detailLine2 = Rez.Strings.ActiveLastSplit + ": " + FormatUtils.formatMillis(listeningSplit);
            }
        } else if (state == Constants.SessionState.STATE_COMPLETE) {
            statusText = Rez.Strings.StateComplete;
            statusColor = Constants.COLOR_ACCENT;
            primaryText = FormatUtils.formatMillis(session.totalTimeMs);
            primaryFont = Graphics.FONT_NUMBER_THAI_HOT;
            detailLine1 = FormatUtils.formatShotCount(session.shotCount);
            var finalSplit = session.lastSplit();
            if (finalSplit == null) {
                detailLine2 = Rez.Strings.ActiveLastSplit + ": --";
            } else {
                detailLine2 = Rez.Strings.ActiveLastSplit + ": " + FormatUtils.formatMillis(finalSplit);
            }
        }

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(centerX, 2, Graphics.FONT_XTINY, gpsStatus, Graphics.TEXT_JUSTIFY_CENTER);
        drawProgressBar(dc, 20, 14, width - 40, 4, gpsProgress, gpsColor);

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.drawText(centerX, 22, Graphics.FONT_SMALL, Rez.Strings.ActiveTitle, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.fillRectangle(20, 40, width - 40, 1);

        dc.setColor(statusColor, Constants.COLOR_BG);
        dc.drawText(centerX, 48, Graphics.FONT_XTINY, statusText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.drawText(centerX, centerY - 8, primaryFont, primaryText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var detailY = centerY + 38;
        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.drawText(centerX, detailY, Graphics.FONT_MEDIUM, detailLine1, Graphics.TEXT_JUSTIFY_CENTER);

        var detailTwoY = detailY + 16;
        if (detailTwoY > height - 12) {
            detailTwoY = height - 12;
        }
        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(centerX, detailTwoY, Graphics.FONT_XTINY, detailLine2, Graphics.TEXT_JUSTIFY_CENTER);
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

    hidden function drawProgressBar(dc as Graphics.Dc, x as Number, y as Number, width as Number, barHeight as Number, progressPct as Number, color as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Constants.COLOR_BG);
        dc.fillRoundedRectangle(x, y, width, barHeight, 2);

        var clamped = DeviceUtils.clamp(progressPct, 0, 100);
        if (clamped <= 0) {
            return;
        }
        var fillWidth = (width * clamped) / 100;
        if (fillWidth < 2) {
            fillWidth = 2;
        }
        dc.setColor(color, Constants.COLOR_BG);
        dc.fillRoundedRectangle(x, y, fillWidth, barHeight, 2);
    }
}
