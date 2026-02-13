import Toybox.Math;
import Toybox.System;
import Toybox.Lang;

class TimerEngine {
    var _sessionStartMs as Number;
    var _countdownEndMs as Number;
    var _countdownSeconds as Number;

    function initialize() {
        _sessionStartMs = 0;
        _countdownEndMs = 0;
        _countdownSeconds = Constants.DEFAULT_COUNTDOWN_SECONDS;
    }

    function setCountdownSeconds(value as Number) as Void {
        var whole = Math.round(value);
        if (whole < 1) {
            _countdownSeconds = 1;
            return;
        }
        _countdownSeconds = whole;
    }

    function startCountdown() as Void {
        _countdownEndMs = System.getTimer() + (_countdownSeconds * 1000);
    }

    function cancelCountdown() as Void {
        _countdownEndMs = 0;
    }

    function countdownRemainingMs() as Number {
        var remaining = _countdownEndMs - System.getTimer();
        if (remaining < 0) {
            return 0;
        }
        return remaining;
    }

    function countdownSecondsRemaining() as Number {
        var remainingMs = countdownRemainingMs();
        return Math.floor((remainingMs + 999) / 1000);
    }

    function beginSessionNow() as Number {
        _sessionStartMs = System.getTimer();
        return _sessionStartMs;
    }

    function nowMs() as Number {
        return System.getTimer();
    }

    function elapsedMs() as Number {
        var now = System.getTimer();
        if (_sessionStartMs <= 0) {
            return 0;
        }
        return now - _sessionStartMs;
    }
}
