import Toybox.Graphics;
import Toybox.WatchUi;

class SettingsInfoView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var centerX = dc.getWidth() / 2;
        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.clear();

        dc.drawText(centerX, 24, Graphics.FONT_SMALL, Rez.Strings.SettingsTitle, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 62, Graphics.FONT_TINY, Rez.Strings.SettingsHintLine1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 82, Graphics.FONT_TINY, Rez.Strings.SettingsHintLine2, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 116, Graphics.FONT_XTINY, Rez.Strings.SettingsHintLine3, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
