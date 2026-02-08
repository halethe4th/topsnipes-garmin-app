import Toybox.Graphics;
import Toybox.WatchUi;

class MainMenuView extends WatchUi.View {
    var _items as Array<String>;
    var _selected as Number;

    function initialize() {
        View.initialize();
        _items = [
            Rez.Strings.MenuNewSession,
            Rez.Strings.MenuHistory,
            Rez.Strings.MenuSync,
            Rez.Strings.MenuSettings
        ];
        _selected = 0;
    }

    function move(delta as Number) as Void {
        _selected += delta;
        if (_selected < 0) {
            _selected = _items.size() - 1;
        }
        if (_selected >= _items.size()) {
            _selected = 0;
        }
        WatchUi.requestUpdate();
    }

    function selectedIndex() as Number {
        return _selected;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var rowHeight = 28;
        var startY = 38;

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.clear();

        dc.drawText(width / 2, 12, Graphics.FONT_SMALL, Rez.Strings.AppName, Graphics.TEXT_JUSTIFY_CENTER);

        for (var i = 0; i < _items.size(); i += 1) {
            var y = startY + (i * rowHeight);
            if (i == _selected) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Constants.COLOR_BG);
                dc.fillRoundedRectangle(18, y - 3, width - 36, 22, 6);
                dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
            }
            dc.drawText(width / 2, y, Graphics.FONT_TINY, _items[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(width / 2, dc.getHeight() - 16, Graphics.FONT_XTINY, Rez.Strings.MainMenuHint, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
