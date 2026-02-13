import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;


module DeviceUtils {
    function isRound(dc as Graphics.Dc) as Boolean {
        return dc.getWidth() == dc.getHeight();
    }

    function deviceLabel() as String {
        var settings = System.getDeviceSettings();
        if (settings has :partNumber) {
            return settings.partNumber;
        }
        return "unknown-device";
    }

    function clamp(value as Number, low as Number, high as Number) as Number {
        if (value < low) {
            return low;
        }
        if (value > high) {
            return high;
        }
        return value;
    }
}
