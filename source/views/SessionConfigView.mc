import Toybox.Graphics;
import Toybox.WatchUi;

class SessionConfigView extends WatchUi.View {
    var _selectedRow as Number;
    var _weaponType as Number;
    var _drillType as Number;
    var _maxShots as Number;

    function initialize() {
        View.initialize();
        _selectedRow = 0;
        _weaponType = Constants.WeaponType.WEAPON_HANDGUN;
        _drillType = Constants.DrillType.DRILL_FREESTYLE;
        _maxShots = 0;
    }

    function moveRow(delta as Number) as Void {
        _selectedRow += delta;
        if (_selectedRow < 0) {
            _selectedRow = 3;
        }
        if (_selectedRow > 3) {
            _selectedRow = 0;
        }
        WatchUi.requestUpdate();
    }

    function adjustSelected(delta as Number) as Void {
        if (_selectedRow == 0) {
            _weaponType += delta;
            if (_weaponType < Constants.WeaponType.WEAPON_HANDGUN) {
                _weaponType = Constants.WeaponType.WEAPON_CARBINE;
            }
            if (_weaponType > Constants.WeaponType.WEAPON_CARBINE) {
                _weaponType = Constants.WeaponType.WEAPON_HANDGUN;
            }
        } else if (_selectedRow == 1) {
            _drillType += delta;
            if (_drillType < Constants.DrillType.DRILL_FREESTYLE) {
                _drillType = Constants.DrillType.DRILL_DOT_TORTURE;
            }
            if (_drillType > Constants.DrillType.DRILL_DOT_TORTURE) {
                _drillType = Constants.DrillType.DRILL_FREESTYLE;
            }
        } else if (_selectedRow == 2) {
            _maxShots += delta;
            if (_maxShots < 0) {
                _maxShots = 0;
            }
            if (_maxShots > 60) {
                _maxShots = 60;
            }
        }
        WatchUi.requestUpdate();
    }

    function selectedRow() as Number {
        return _selectedRow;
    }

    function weaponType() as Number {
        return _weaponType;
    }

    function drillType() as Number {
        return _drillType;
    }

    function maxShots() as Number {
        return _maxShots;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.clear();

        dc.drawText(width / 2, 10, Graphics.FONT_SMALL, Rez.Strings.ConfigTitle, Graphics.TEXT_JUSTIFY_CENTER);

        drawRow(dc, 0, 42, Rez.Strings.ConfigWeapon, Constants.weaponLabel(_weaponType));
        drawRow(dc, 1, 68, Rez.Strings.ConfigDrill, Constants.drillLabel(_drillType));

        var shotsLabel = Rez.Strings.ConfigUnlimited;
        if (_maxShots > 0) {
            shotsLabel = _maxShots.toString();
        }
        drawRow(dc, 2, 94, Rez.Strings.ConfigMaxShots, shotsLabel);
        drawRow(dc, 3, 130, Rez.Strings.ConfigStart, Rez.Strings.ConfigStartValue);

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(width / 2, dc.getHeight() - 14, Graphics.FONT_XTINY, Rez.Strings.ConfigHint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawRow(dc as Graphics.Dc, row as Number, y as Number, title as String, value as String) as Void {
        var width = dc.getWidth();
        if (_selectedRow == row) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Constants.COLOR_BG);
            dc.fillRoundedRectangle(16, y - 2, width - 32, 20, 5);
            dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        }

        dc.drawText(24, y + 1, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(width - 24, y + 1, Graphics.FONT_XTINY, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }
}
