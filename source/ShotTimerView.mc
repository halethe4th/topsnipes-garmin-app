using Toybox.Application;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

class ShotTimerView extends WatchUi.View {
    const MIN_SHOT_INTERVAL_MS = 80;
    const MAX_SESSION_HISTORY = 75;
    const APP_DATA_VERSION = 2;

    const STATE_IDLE = 0;
    const STATE_COUNTDOWN = 1;
    const STATE_RUNNING = 2;
    const STATE_FINISHED = 3;

    var _state = STATE_IDLE;
    var _countdownSeconds = 3;
    var _countdownEndMs = 0;

    var _sessionStartMs = 0;
    var _shotTimes = [];
    var _splitTimes = [];
    var _reloadSplits = [];
    var _drawToFirstMs = null;
    var _lastShotRegisteredMs = 0;

    var _sessionName = "M17 (9mm)";
    var _weaponOptions = [
        "M17 (9mm)",
        "M18 (9mm)",
        "Glock 19 (9mm)",
        "Glock 17 (9mm)",
        "M9 (9mm)",
        "1911 (.45 ACP)",
        "Sig P320 XCarry (9mm)",
        "M4A1 (5.56)",
        "M16A4 (5.56)",
        "M27 IAR (5.56)",
        "MK18 (5.56)",
        "HK416 (5.56)",
        "M110 (7.62)",
        "M40A6 (7.62)",
        "M249 SAW (5.56)",
        "M240B (7.62)",
        "M1014 (12ga)",
        "Mossberg 590 (12ga)",
        "Custom Handgun",
        "Custom Rifle",
        "Custom Shotgun"
    ];
    var _weaponIndex = 0;

    var _stats = null;
    var _tickTimer = null;
    var _summaryPage = 0;
    var _summaryPages = 3;
    var _fitSession = null;

    function initialize() {
        View.initialize();
        _tickTimer = new Timer.Timer();
        loadWeaponPreference();
    }

    function onShow() {
        _tickTimer.start(method(:onTick), 100, true);
    }

    function onHide() {
        _tickTimer.stop();
    }

    function onTick() {
        WatchUi.requestUpdate();
    }

    function handleKey(key) {
        if (key == WatchUi.KEY_MENU || key == WatchUi.KEY_DOWN) {
            if (_state == STATE_FINISHED) {
                _summaryPage = _summaryPage - 1;
                if (_summaryPage < 0) {
                    _summaryPage = _summaryPages - 1;
                }
                WatchUi.requestUpdate();
                return true;
            }
            if (_state == STATE_IDLE || _state == STATE_FINISHED) {
                cycleWeapon();
                return true;
            }
        }

        if (key == WatchUi.KEY_START) {
            if (_state == STATE_IDLE || _state == STATE_FINISHED) {
                startCountdown();
                return true;
            }
        }

        if (key == WatchUi.KEY_ENTER) {
            if (_state == STATE_COUNTDOWN) {
                return true;
            }

            if (_state == STATE_RUNNING) {
                registerShot();
                return true;
            }

            if (_state == STATE_IDLE || _state == STATE_FINISHED) {
                startCountdown();
                return true;
            }
        }

        if (key == WatchUi.KEY_ESC) {
            if (_state == STATE_RUNNING || _state == STATE_COUNTDOWN) {
                finishSession();
                return true;
            }

            if (_state == STATE_FINISHED) {
                resetSession();
                return true;
            }
        }

        if (key == WatchUi.KEY_UP && _state == STATE_FINISHED) {
            _summaryPage = (_summaryPage + 1) % _summaryPages;
            WatchUi.requestUpdate();
            return true;
        }

        return false;
    }

    function startCountdown() {
        _shotTimes = [];
        _splitTimes = [];
        _reloadSplits = [];
        _drawToFirstMs = null;
        _lastShotRegisteredMs = 0;
        _stats = null;
        _summaryPage = 0;
        _state = STATE_COUNTDOWN;
        _countdownEndMs = System.getTimer() + (_countdownSeconds * 1000);
        WatchUi.requestUpdate();
    }

    function registerShot() {
        var now = System.getTimer();
        if (_lastShotRegisteredMs > 0 && (now - _lastShotRegisteredMs) < MIN_SHOT_INTERVAL_MS) {
            return;
        }

        if (_shotTimes.size() == 0) {
            _drawToFirstMs = now - _sessionStartMs;
            _shotTimes.add(now);
            _lastShotRegisteredMs = now;
            return;
        }

        var lastShot = _shotTimes[_shotTimes.size() - 1];
        var split = now - lastShot;
        _shotTimes.add(now);
        _splitTimes.add(split);
        _lastShotRegisteredMs = now;

        if (split >= 1800) {
            _reloadSplits.add(split);
        }
    }

    function finishSession() {
        if (_state == STATE_COUNTDOWN) {
            resetSession();
            return;
        }

        _state = STATE_FINISHED;
        _stats = calculateMetrics();
        _summaryPage = 0;
        if (_stats[:shotCount] > 0) {
            stopFitRecording(true);
            saveLastSession(_stats);
            saveSessionHistory(_stats);
        } else {
            stopFitRecording(false);
        }
        WatchUi.requestUpdate();
    }

    function resetSession() {
        _state = STATE_IDLE;
        _shotTimes = [];
        _splitTimes = [];
        _reloadSplits = [];
        _drawToFirstMs = null;
        _stats = null;
        _summaryPage = 0;
        stopFitRecording(false);
        WatchUi.requestUpdate();
    }

    function cycleWeapon() {
        _weaponIndex = (_weaponIndex + 1) % _weaponOptions.size();
        _sessionName = _weaponOptions[_weaponIndex];
        Application.Storage.setValue("topsnipes_weapon_index", _weaponIndex);
        WatchUi.requestUpdate();
    }

    function calculateMetrics() {
        var totalShots = _shotTimes.size();
        var elapsed = 0;

        if (totalShots > 0) {
            elapsed = _shotTimes[totalShots - 1] - _sessionStartMs;
        }

        var avgSplit = average(_splitTimes);
        var splitStdDev = standardDeviation(_splitTimes, avgSplit);
        var cadenceBands = buildCadenceBands(_splitTimes);
        var transitionCount = countTransitions(_splitTimes);
        var fastStreak = longestFastStreak(_splitTimes, 260);
        var firstThreeAvg = averageSlice(_splitTimes, 0, 3);
        var lastThreeAvg = averageLast(_splitTimes, 3);
        var fatigueDelta = null;
        if (firstThreeAvg != null && lastThreeAvg != null) {
            fatigueDelta = lastThreeAvg - firstThreeAvg;
        }
        var burstRatio = ratio(cadenceBands[:aggressive] + cadenceBands[:combat], _splitTimes.size());
        var controlRatio = ratio(cadenceBands[:control], _splitTimes.size());
        var cadenceScore = scoreCadence(avgSplit, splitStdDev);
        var executionScore = scoreExecution(transitionCount, _reloadSplits.size(), fatigueDelta);
        var readinessScore = Math.round((cadenceScore * 0.55) + (executionScore * 0.45));

        var stats = {
            :dataVersion => APP_DATA_VERSION,
            :weapon => _sessionName,
            :shotCount => totalShots,
            :elapsedMs => elapsed,
            :drawToFirstMs => _drawToFirstMs,
            :avgSplitMs => avgSplit,
            :bestSplitMs => minVal(_splitTimes),
            :worstSplitMs => maxVal(_splitTimes),
            :splitStdDevMs => splitStdDev,
            :reloadCount => _reloadSplits.size(),
            :avgReloadMs => average(_reloadSplits),
            :transitionCount => transitionCount,
            :longestFastStreak => fastStreak,
            :firstThreeAvgMs => firstThreeAvg,
            :lastThreeAvgMs => lastThreeAvg,
            :fatigueDeltaMs => fatigueDelta,
            :burstRatio => burstRatio,
            :controlRatio => controlRatio,
            :cadenceScore => cadenceScore,
            :executionScore => executionScore,
            :readinessScore => readinessScore,
            :cadenceBands => cadenceBands,
            :splits => _splitTimes,
            :shots => buildShotRecords(),
        };

        return stats;
    }

    function saveLastSession(stats) {
        Application.Storage.setValue("topsnipes_last_session", stats);
    }

    function saveSessionHistory(stats) {
        var history = Application.Storage.getValue("topsnipes_session_history");
        if (history == null) {
            history = [];
        }

        history.add(stats);
        while (history.size() > MAX_SESSION_HISTORY) {
            history.remove(0);
        }

        Application.Storage.setValue("topsnipes_session_history", history);
    }

    function loadWeaponPreference() {
        var savedIndex = Application.Storage.getValue("topsnipes_weapon_index");
        if (savedIndex == null) {
            _weaponIndex = 0;
            _sessionName = _weaponOptions[0];
            return;
        }

        if (savedIndex < 0 || savedIndex >= _weaponOptions.size()) {
            _weaponIndex = 0;
            _sessionName = _weaponOptions[0];
            return;
        }

        _weaponIndex = savedIndex;
        _sessionName = _weaponOptions[_weaponIndex];
    }

    function buildShotRecords() {
        var records = [];
        for (var i = 0; i < _shotTimes.size(); i += 1) {
            var elapsed = _shotTimes[i] - _sessionStartMs;
            var split = 0;
            if (i > 0) {
                split = _shotTimes[i] - _shotTimes[i - 1];
            }
            records.add({
                :num => i + 1,
                :elapsed => elapsed,
                :split => split,
                :isReload => split >= 1800,
                :phase => classifyPhase(split)
            });
        }
        return records;
    }

    function buildCadenceBands(splits) {
        var bands = {
            :aggressive => 0,
            :combat => 0,
            :control => 0,
            :recovery => 0
        };
        for (var i = 0; i < splits.size(); i += 1) {
            var split = splits[i];
            if (split <= 220) {
                bands[:aggressive] += 1;
            } else if (split <= 320) {
                bands[:combat] += 1;
            } else if (split <= 900) {
                bands[:control] += 1;
            } else {
                bands[:recovery] += 1;
            }
        }
        return bands;
    }

    function countTransitions(splits) {
        var count = 0;
        for (var i = 0; i < splits.size(); i += 1) {
            if (splits[i] >= 900 && splits[i] < 1800) {
                count += 1;
            }
        }
        return count;
    }

    function longestFastStreak(splits, threshold) {
        var best = 0;
        var current = 0;
        for (var i = 0; i < splits.size(); i += 1) {
            if (splits[i] > 0 && splits[i] <= threshold) {
                current += 1;
                if (current > best) {
                    best = current;
                }
            } else {
                current = 0;
            }
        }
        return best;
    }

    function classifyPhase(split) {
        if (split <= 0) {
            return "start";
        }
        if (split >= 1800) {
            return "reload";
        }
        if (split >= 900) {
            return "transition";
        }
        if (split <= 260) {
            return "cadence";
        }
        return "control";
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var centerX = w / 2;

        drawTitle(dc, centerX);

        if (_state == STATE_COUNTDOWN) {
            var msRemaining = _countdownEndMs - System.getTimer();
            if (msRemaining <= 0) {
                _state = STATE_RUNNING;
                _sessionStartMs = System.getTimer();
                startFitRecording();
                msRemaining = 0;
            }
            var seconds = Math.floor((msRemaining + 999) / 1000);
            drawBigTimer(dc, centerX, h, seconds.toString());
            drawFooter(dc, "ENTER=SHOT  STOP=END");
            return;
        }

        if (_state == STATE_RUNNING) {
            var elapsed = System.getTimer() - _sessionStartMs;
            drawBigTimer(dc, centerX, h, formatMs(elapsed));

            var shotLine = "Shots " + _shotTimes.size().toString();
            dc.drawText(centerX, h - 72, Graphics.FONT_TINY, shotLine, Graphics.TEXT_JUSTIFY_CENTER);

            var splitText = "Split --";
            if (_splitTimes.size() > 0) {
                splitText = "Last " + formatMs(_splitTimes[_splitTimes.size() - 1]);
            }
            dc.drawText(centerX, h - 56, Graphics.FONT_TINY, splitText, Graphics.TEXT_JUSTIFY_CENTER);
            drawFooter(dc, "ENTER=SHOT  STOP=END");
            return;
        }

        if (_state == STATE_FINISHED && _stats != null) {
            drawSummary(dc, w, h, _stats);
            drawFooter(dc, "UP/DOWN=PAGE  ESC=RESET  START=NEW");
            return;
        }

        drawBigTimer(dc, centerX, h, "READY");
        dc.drawText(centerX, h - 72, Graphics.FONT_TINY, "Weapon " + _sessionName, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, h - 56, Graphics.FONT_TINY, "MENU=CHANGE", Graphics.TEXT_JUSTIFY_CENTER);
        drawFooter(dc, "START/ENTER=GO");
    }

    function drawTitle(dc, x) {
        drawBrandMark(dc, 22, 24);
        dc.drawText(x, 24, Graphics.FONT_SMALL, "TOPSNIPES SHOT TIMER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawLine(20, 34, dc.getWidth() - 20, 34);
    }

    function drawBrandMark(dc, x, y) {
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
        dc.fillCircle(x, y, 10);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_YELLOW);
        dc.drawText(x, y - 7, Graphics.FONT_XTINY, "TS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function startFitRecording() {
        if (!(Toybox has :ActivityRecording)) {
            return;
        }
        if (_fitSession != null && _fitSession.isRecording()) {
            return;
        }
        try {
            _fitSession = ActivityRecording.createSession({
                :name => "TopSnipes Shooting",
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
            _fitSession.start();
        } catch (ex) {
            System.println("FIT start failed: " + ex.toString());
            _fitSession = null;
        }
    }

    function stopFitRecording(shouldSave) {
        if (_fitSession == null) {
            return;
        }
        try {
            if (_fitSession.isRecording()) {
                _fitSession.stop();
            }
            if (shouldSave) {
                _fitSession.save();
            } else {
                _fitSession.discard();
            }
        } catch (ex) {
            System.println("FIT stop failed: " + ex.toString());
        }
        _fitSession = null;
    }

    function drawBigTimer(dc, centerX, h, value) {
        dc.drawText(centerX, h / 2, Graphics.FONT_LARGE, value, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawSummary(dc, width, height, stats) {
        var pageTitle = "SUMMARY";
        if (_summaryPage == 1) {
            pageTitle = "CADENCE";
        } else if (_summaryPage == 2) {
            pageTitle = "READINESS";
        }
        dc.drawText(width / 2, 56, Graphics.FONT_SMALL, pageTitle + " (" + (_summaryPage + 1).toString() + "/3)", Graphics.TEXT_JUSTIFY_CENTER);

        if (_summaryPage == 0) {
            dc.drawText(10, 76, Graphics.FONT_TINY, "Weapon: " + stats[:weapon]);
            dc.drawText(10, 92, Graphics.FONT_TINY, "Shots: " + stats[:shotCount].toString());
            dc.drawText(10, 108, Graphics.FONT_TINY, "Draw->1st: " + formatMaybe(stats[:drawToFirstMs]));
            dc.drawText(10, 124, Graphics.FONT_TINY, "Avg Split: " + formatMaybe(stats[:avgSplitMs]));
            dc.drawText(10, 140, Graphics.FONT_TINY, "Best/Worst: " + formatMaybe(stats[:bestSplitMs]) + " / " + formatMaybe(stats[:worstSplitMs]));
            dc.drawText(10, 156, Graphics.FONT_TINY, "Split SD: " + formatMaybe(stats[:splitStdDevMs]));
            dc.drawText(10, 172, Graphics.FONT_TINY, "Reloads: " + stats[:reloadCount].toString() + " (avg " + formatMaybe(stats[:avgReloadMs]) + ")");
            dc.drawText(10, 188, Graphics.FONT_TINY, "Elapsed: " + formatMs(stats[:elapsedMs]));
            return;
        }

        if (_summaryPage == 1) {
            dc.drawText(10, 76, Graphics.FONT_TINY, "Aggressive: " + stats[:cadenceBands][:aggressive].toString());
            dc.drawText(10, 92, Graphics.FONT_TINY, "Combat: " + stats[:cadenceBands][:combat].toString());
            dc.drawText(10, 108, Graphics.FONT_TINY, "Control: " + stats[:cadenceBands][:control].toString());
            dc.drawText(10, 124, Graphics.FONT_TINY, "Recovery: " + stats[:cadenceBands][:recovery].toString());
            dc.drawText(10, 140, Graphics.FONT_TINY, "Transitions: " + stats[:transitionCount].toString());
            dc.drawText(10, 156, Graphics.FONT_TINY, "Fast streak: " + stats[:longestFastStreak].toString());
            dc.drawText(10, 172, Graphics.FONT_TINY, "Burst ratio: " + formatPercent(stats[:burstRatio]));
            dc.drawText(10, 188, Graphics.FONT_TINY, "Control ratio: " + formatPercent(stats[:controlRatio]));
            return;
        }

        dc.drawText(10, 76, Graphics.FONT_TINY, "First3 avg: " + formatMaybe(stats[:firstThreeAvgMs]));
        dc.drawText(10, 92, Graphics.FONT_TINY, "Last3 avg: " + formatMaybe(stats[:lastThreeAvgMs]));
        dc.drawText(10, 108, Graphics.FONT_TINY, "Fatigue delta: " + formatSigned(stats[:fatigueDeltaMs]));
        dc.drawText(10, 124, Graphics.FONT_TINY, "Cadence score: " + stats[:cadenceScore].toString());
        dc.drawText(10, 140, Graphics.FONT_TINY, "Execution score: " + stats[:executionScore].toString());
        dc.drawText(10, 156, Graphics.FONT_TINY, "Readiness: " + stats[:readinessScore].toString());
        dc.drawText(10, 172, Graphics.FONT_TINY, "Data version: " + stats[:dataVersion].toString());
        dc.drawText(10, 188, Graphics.FONT_TINY, "UP/DOWN pages");
    }

    function drawFooter(dc, text) {
        dc.drawText(dc.getWidth() / 2, dc.getHeight() - 20, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function average(values) {
        if (values.size() == 0) {
            return null;
        }

        var sum = 0;
        for (var i = 0; i < values.size(); i += 1) {
            sum += values[i];
        }

        return sum / values.size();
    }

    function standardDeviation(values, mean) {
        if (values.size() < 2 || mean == null) {
            return null;
        }

        var varianceSum = 0.0;
        for (var i = 0; i < values.size(); i += 1) {
            var diff = values[i] - mean;
            varianceSum += diff * diff;
        }

        var variance = varianceSum / values.size();
        return Math.sqrt(variance);
    }

    function averageSlice(values, startIdx, count) {
        if (values.size() == 0 || count <= 0) {
            return null;
        }
        var endIdx = startIdx + count;
        if (endIdx > values.size()) {
            endIdx = values.size();
        }
        var sum = 0;
        var used = 0;
        for (var i = startIdx; i < endIdx; i += 1) {
            sum += values[i];
            used += 1;
        }
        if (used == 0) {
            return null;
        }
        return sum / used;
    }

    function averageLast(values, count) {
        if (values.size() == 0 || count <= 0) {
            return null;
        }
        var start = values.size() - count;
        if (start < 0) {
            start = 0;
        }
        return averageSlice(values, start, count);
    }

    function ratio(part, total) {
        if (total <= 0) {
            return 0.0;
        }
        return (part * 1.0) / total;
    }

    function scoreCadence(avgSplit, splitStdDev) {
        var avg = avgSplit;
        if (avg == null) {
            avg = 700;
        }
        var sd = splitStdDev;
        if (sd == null) {
            sd = 400;
        }
        var score = 100 - Math.round((avg / 8.5) + (sd / 5.5));
        if (score < 0) {
            score = 0;
        }
        if (score > 100) {
            score = 100;
        }
        return score;
    }

    function scoreExecution(transitions, reloads, fatigueDelta) {
        var fatiguePenalty = 0;
        if (fatigueDelta != null && fatigueDelta > 0) {
            fatiguePenalty = Math.round(fatigueDelta / 28);
        }
        var score = 100 - (transitions * 3) - (reloads * 4) - fatiguePenalty;
        if (score < 0) {
            score = 0;
        }
        if (score > 100) {
            score = 100;
        }
        return score;
    }

    function minVal(values) {
        if (values.size() == 0) {
            return null;
        }

        var best = values[0];
        for (var i = 1; i < values.size(); i += 1) {
            if (values[i] < best) {
                best = values[i];
            }
        }
        return best;
    }

    function maxVal(values) {
        if (values.size() == 0) {
            return null;
        }

        var worst = values[0];
        for (var i = 1; i < values.size(); i += 1) {
            if (values[i] > worst) {
                worst = values[i];
            }
        }
        return worst;
    }

    function formatMaybe(value) {
        if (value == null) {
            return "--";
        }
        return formatMs(value);
    }

    function formatMs(ms) {
        if (ms == null) {
            return "--";
        }

        var totalMs = ms;
        var wholeSeconds = Math.floor(totalMs / 1000);
        var millis = totalMs % 1000;
        var millisText = millis.toString();
        if (millis < 100) {
            millisText = "0" + millisText;
        }
        if (millis < 10) {
            millisText = "0" + millisText;
        }

        return wholeSeconds.toString() + "." + millisText + "s";
    }

    function formatPercent(value) {
        return Math.round(value * 100).toString() + "%";
    }

    function formatSigned(ms) {
        if (ms == null) {
            return "--";
        }
        var rounded = Math.round(ms);
        if (rounded > 0) {
            return "+" + rounded.toString() + "ms";
        }
        return rounded.toString() + "ms";
    }
}
