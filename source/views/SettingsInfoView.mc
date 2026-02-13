import Toybox.Application;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

class SettingsInfoView extends WatchUi.View {
    var _selected as Number;
    var _offset as Number;
    var _countdownSecs as Number;
    var _sensitivity as Number;
    var _debounceMs as Number;
    var _maxShots as Number;
    var _autoStop as Boolean;
    var _hapticOnShot as Boolean;
    var _hapticOnStart as Boolean;

    function initialize() {
        View.initialize();
        _selected = 0;
        _offset = 0;
        _countdownSecs = readNumber("countdownSecs", Constants.DEFAULT_COUNTDOWN_SECONDS);
        _sensitivity = readNumber("sensitivity", Constants.DEFAULT_SENSITIVITY);
        _debounceMs = readNumber("debounceMs", Constants.DEFAULT_DEBOUNCE_MS);
        _maxShots = readNumber("maxShots", Constants.DEFAULT_MAX_SHOTS);
        _autoStop = readBool("autoStopEnabled", true);
        _hapticOnShot = readBool("hapticOnShot", true);
        _hapticOnStart = readBool("hapticOnStart", true);
    }

    function move(delta as Number) as Void {
        _selected += delta;
        if (_selected < 0) {
            _selected = rowCount() - 1;
        }
        if (_selected >= rowCount()) {
            _selected = 0;
        }
        adjustOffsetForSelection();
        WatchUi.requestUpdate();
    }

    function adjustSelected(delta as Number) as Void {
        if (_selected == 0) {
            _countdownSecs = clampNumber(_countdownSecs + delta, 1, 30);
            persistNumber("countdownSecs", _countdownSecs);
        } else if (_selected == 1) {
            _sensitivity = clampNumber(_sensitivity + delta, 1, 10);
            persistNumber("sensitivity", _sensitivity);
        } else if (_selected == 2) {
            _debounceMs = clampNumber(_debounceMs + (delta * 10), 50, 600);
            persistNumber("debounceMs", _debounceMs);
        } else if (_selected == 3) {
            _maxShots = clampNumber(_maxShots + delta, 0, Constants.MAX_SHOTS_LIMIT);
            persistNumber("maxShots", _maxShots);
        } else if (_selected == 4) {
            _autoStop = !_autoStop;
            persistBool("autoStopEnabled", _autoStop);
        } else if (_selected == 5) {
            _hapticOnShot = !_hapticOnShot;
            persistBool("hapticOnShot", _hapticOnShot);
        } else if (_selected == 6) {
            _hapticOnStart = !_hapticOnStart;
            persistBool("hapticOnStart", _hapticOnStart);
        }

        var manager = AppContext.sessionManager();
        if (manager != null) {
            manager.loadUserSettings();
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var centerX = width / 2;

        dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
        dc.clear();
        dc.drawText(centerX, 8, Graphics.FONT_SMALL, Rez.Strings.SettingsTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var items = buildRows();
        var rowY = 30;
        for (var i = _offset; i < items.size(); i += 1) {
            if (i >= _offset + 5) {
                break;
            }
            var row = items[i] as Dictionary;
            if (i == _selected) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Constants.COLOR_BG);
                dc.fillRoundedRectangle(12, rowY - 2, width - 24, 22, 5);
            }
            dc.setColor(Constants.COLOR_TEXT, Constants.COLOR_BG);
            dc.drawText(20, rowY + 1, Graphics.FONT_XTINY, trimText(row["label"].toString(), 17), Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(width - 20, rowY + 1, Graphics.FONT_XTINY, trimText(row["value"].toString(), 8), Graphics.TEXT_JUSTIFY_RIGHT);
            rowY += 24;
        }

        dc.setColor(Constants.COLOR_SUBTLE, Constants.COLOR_BG);
        dc.drawText(centerX, dc.getHeight() - 14, Graphics.FONT_XTINY, Rez.Strings.SettingsEditHint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function buildRows() as Array<Dictionary> {
        var maxShotsLabel = _maxShots.toString();
        if (_maxShots == 0) {
            maxShotsLabel = Rez.Strings.ConfigUnlimited;
        }

        var rows = [] as Array<Dictionary>;
        rows.add({
            "label" => Rez.Strings.SettingCountdownTitle,
            "value" => _countdownSecs.toString()
        });
        rows.add({
            "label" => Rez.Strings.SettingSensitivityTitle,
            "value" => _sensitivity.toString()
        });
        rows.add({
            "label" => Rez.Strings.SettingDebounceTitle,
            "value" => _debounceMs.toString()
        });
        rows.add({
            "label" => Rez.Strings.SettingMaxShotsTitle,
            "value" => maxShotsLabel
        });
        rows.add({
            "label" => Rez.Strings.SettingAutoStopTitle,
            "value" => boolLabel(_autoStop)
        });
        rows.add({
            "label" => Rez.Strings.SettingHapticShotTitle,
            "value" => boolLabel(_hapticOnShot)
        });
        rows.add({
            "label" => Rez.Strings.SettingHapticStartTitle,
            "value" => boolLabel(_hapticOnStart)
        });
        return rows;
    }

    hidden function boolLabel(value as Boolean) as String {
        if (value) {
            return "ON";
        }
        return "OFF";
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

    hidden function rowCount() as Number {
        return 7;
    }

    hidden function adjustOffsetForSelection() as Void {
        if (_selected < _offset) {
            _offset = _selected;
        }
        if (_selected >= (_offset + 5)) {
            _offset = _selected - 4;
        }
    }

    hidden function clampNumber(value as Number, minimum as Number, maximum as Number) as Number {
        if (value < minimum) {
            return minimum;
        }
        if (value > maximum) {
            return maximum;
        }
        return value;
    }

    hidden function readNumber(key as String, fallback as Number) as Number {
        if (!(Application has :Properties)) {
            return fallback;
        }
        try {
            var value = Application.Properties.getValue(key);
            if (value == null) {
                return fallback;
            }
            if (value instanceof Number) {
                return value as Number;
            }
            if (value instanceof String) {
                return (value as String).toNumber();
            }
            return fallback;
        } catch (ex) {
            return fallback;
        }
    }

    hidden function readBool(key as String, fallback as Boolean) as Boolean {
        if (!(Application has :Properties)) {
            return fallback;
        }
        try {
            var value = Application.Properties.getValue(key);
            if (value == null) {
                return fallback;
            }
            if (value instanceof Boolean) {
                return value as Boolean;
            }
            if (value instanceof Number) {
                return (value as Number) != 0;
            }
            if (value instanceof String) {
                var text = value as String;
                return text == "true" || text == "TRUE" || text == "1" || text == "yes" || text == "YES";
            }
            return fallback;
        } catch (ex) {
            return fallback;
        }
    }

    hidden function persistNumber(key as String, value as Number) as Void {
        if (!(Application has :Properties)) {
            return;
        }
        try {
            Application.Properties.setValue(key, value);
        } catch (ex) {
            LogUtils.debug("Settings write failed: " + key);
        }
    }

    hidden function persistBool(key as String, value as Boolean) as Void {
        if (!(Application has :Properties)) {
            return;
        }
        try {
            Application.Properties.setValue(key, value);
        } catch (ex) {
            LogUtils.debug("Settings write failed: " + key);
        }
    }
}
