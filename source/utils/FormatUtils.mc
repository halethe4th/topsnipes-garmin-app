import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

module FormatUtils {
    function formatMillis(ms as Number or Null) as String {
        if (ms == null) {
            return "--";
        }

        var totalMs = ms;
        if (totalMs < 0) {
            totalMs = 0;
        }

        var seconds = Math.floor(totalMs / 1000);
        var millis = totalMs % 1000;

        var millisText = millis.toString();
        if (millis < 100) {
            millisText = "0" + millisText;
        }
        if (millis < 10) {
            millisText = "0" + millisText;
        }

        return seconds.toString() + "." + millisText;
    }

    function formatShotCount(count as Number) as String {
        if (count == 1) {
            return "1 shot";
        }
        return count.toString() + " shots";
    }

    function formatPercent(value as Number or Null) as String {
        if (value == null) {
            return "--";
        }
        return Math.round(value).toString() + "%";
    }

    function formatClock(epochMs as Number or Null) as String {
        if (epochMs == null) {
            return "--";
        }

        var moment = new Time.Moment(epochMs);
        var localInfo = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
        return Lang.format("$1$/$2$ $3$:$4$", [
            localInfo.month,
            localInfo.day,
            localInfo.hour,
            localInfo.min
        ]);
    }
}
