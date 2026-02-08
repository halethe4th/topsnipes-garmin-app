using Toybox.Application;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Position;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

class ShotTimerView extends WatchUi.View {
    const MIN_SHOT_INTERVAL_MS = 80;
    const MAX_SESSION_HISTORY = 75;
    const APP_DATA_VERSION = 3;
    const SAFE_TOP = 56;
    const SAFE_BOTTOM = 50;
    const GPS_GOOD_ACCURACY_METERS = 35;

    const STATE_IDLE = 0;
    const STATE_COUNTDOWN = 1;
    const STATE_RUNNING = 2;
    const STATE_FINISHED = 3;
    const STATE_SETTINGS = 4;

    var _state = STATE_IDLE;
    var _countdownSeconds = 10;
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
    var _weaponShortOptions = [
        "M17 9mm",
        "M18 9mm",
        "G19 9mm",
        "G17 9mm",
        "M9 9mm",
        "1911 .45",
        "P320 XCarry",
        "M4A1 5.56",
        "M16A4 5.56",
        "M27 IAR 5.56",
        "MK18 5.56",
        "HK416 5.56",
        "M110 7.62",
        "M40A6 7.62",
        "M249 5.56",
        "M240B 7.62",
        "M1014 12ga",
        "M590 12ga",
        "Custom HG",
        "Custom Rifle",
        "Custom SG"
    ];
    var _weaponIndex = 0;

    var _stats = null;
    var _tickTimer = null;
    var _summaryPage = 0;
    var _summaryPages = 3;
    var _fitSession = null;
    var _gpsVerified = false;
    var _gpsStatusText = "GPS CHECKING";
    var _gpsAccuracyMeters = null;
    var _gpsMonitoring = false;
    var _gpsAcquireProgress = 0;
    var _weaponNoticeUntilMs = 0;
    var _gpsVerifiedAtStart = false;
    var _gpsAccuracyAtStart = null;
    var _settingsIndex = 0;
    var _settingsReturnState = STATE_IDLE;
    var _favoriteWeaponIndex = 0;
    var _useFavoriteWeapon = false;
    var _countdownOptions = [3, 5, 7, 10, 12, 15];

    function initialize() {
        View.initialize();
        _tickTimer = new Timer.Timer();
        loadUserPreferences();
    }

    function onShow() {
        _tickTimer.start(method(:onTick), 100, true);
        startGpsMonitoring();
    }

    function onHide() {
        _tickTimer.stop();
        stopGpsMonitoring();
    }

    function onTick() {
        if (!_gpsVerified && _gpsMonitoring) {
            if (_gpsAcquireProgress < 95) {
                _gpsAcquireProgress += 1;
                if (_gpsAcquireProgress > 95) {
                    _gpsAcquireProgress = 95;
                }
            }
            _gpsStatusText = buildGpsStatusText();
        } else if (_gpsVerified) {
            _gpsAcquireProgress = 100;
        }
        WatchUi.requestUpdate();
    }

    function handleKey(key) {
        if (_state == STATE_SETTINGS) {
            return handleSettingsKey(key);
        }

        if (isStartStopInput(key)) {
            if (_state == STATE_RUNNING || _state == STATE_COUNTDOWN) {
                finishSession();
                return true;
            }
            if (_state == STATE_IDLE || _state == STATE_FINISHED) {
                startCountdown();
                return true;
            }
            return true;
        }

        if (_state == STATE_IDLE) {
            if (key == WatchUi.KEY_UP && _stats != null) {
                _state = STATE_FINISHED;
                _summaryPage = 0;
                WatchUi.requestUpdate();
                return true;
            }
            return true;
        }

        if (_state == STATE_COUNTDOWN) {
            if (isEscInput(key)) {
                resetSession();
            }
            return true;
        }

        if (_state == STATE_RUNNING) {
            if (isLapInput(key) || key == WatchUi.KEY_ESC) {
                registerShot();
                return true;
            }
            return true;
        }

        if (_state == STATE_FINISHED) {
            if (isEscInput(key)) {
                resetSession();
                return true;
            }
            if (isSummaryPrevInput(key)) {
                _summaryPage = _summaryPage - 1;
                if (_summaryPage < 0) {
                    _summaryPage = _summaryPages - 1;
                }
                WatchUi.requestUpdate();
                return true;
            }
            if (isSummaryNextInput(key)) {
                _summaryPage = (_summaryPage + 1) % _summaryPages;
                WatchUi.requestUpdate();
                return true;
            }
            return true;
        }

        return true;
    }

    function openSettings() {
        _settingsReturnState = _state;
        _settingsIndex = 0;
        _state = STATE_SETTINGS;
        WatchUi.requestUpdate();
    }

    function openSettingsFromMenu() {
        if (_state == STATE_RUNNING || _state == STATE_COUNTDOWN) {
            return true;
        }
        openSettings();
        return true;
    }

    function closeSettings() {
        if (_settingsReturnState == STATE_FINISHED && _stats != null) {
            _state = STATE_FINISHED;
        } else {
            _state = STATE_IDLE;
        }
        WatchUi.requestUpdate();
    }

    function handleSettingsKey(key) {
        if (isEscInput(key) || key == WatchUi.KEY_MENU) {
            closeSettings();
            return true;
        }

        if (key == WatchUi.KEY_UP) {
            _settingsIndex -= 1;
            if (_settingsIndex < 0) {
                _settingsIndex = 4;
            }
            WatchUi.requestUpdate();
            return true;
        }

        if (key == WatchUi.KEY_DOWN) {
            _settingsIndex = (_settingsIndex + 1) % 5;
            WatchUi.requestUpdate();
            return true;
        }

        if (isStartStopInput(key) || key == WatchUi.KEY_ENTER) {
            applySettingsAction(_settingsIndex);
            return true;
        }

        return true;
    }

    function applySettingsAction(index) {
        if (index == 0) {
            _countdownSeconds = nextCountdownOption(_countdownSeconds);
            Application.Storage.setValue("topsnipes_countdown_seconds", _countdownSeconds);
        } else if (index == 1) {
            cycleWeaponInSettings();
        } else if (index == 2) {
            _favoriteWeaponIndex = _weaponIndex;
            _useFavoriteWeapon = true;
            Application.Storage.setValue("topsnipes_favorite_weapon_index", _favoriteWeaponIndex);
            Application.Storage.setValue("topsnipes_use_favorite_weapon", _useFavoriteWeapon);
        } else if (index == 3) {
            _useFavoriteWeapon = !_useFavoriteWeapon;
            Application.Storage.setValue("topsnipes_use_favorite_weapon", _useFavoriteWeapon);
        } else if (index == 4) {
            clearStoredHistory();
        }
        WatchUi.requestUpdate();
    }

    function cycleWeaponInSettings() {
        _weaponIndex = (_weaponIndex + 1) % _weaponOptions.size();
        _sessionName = _weaponOptions[_weaponIndex];
        _weaponNoticeUntilMs = System.getTimer() + 1400;
        Application.Storage.setValue("topsnipes_weapon_index", _weaponIndex);
    }

    function clearStoredHistory() {
        Application.Storage.setValue("topsnipes_last_session", null);
        Application.Storage.setValue("topsnipes_session_history", []);
    }

    function nextCountdownOption(currentValue) {
        for (var i = 0; i < _countdownOptions.size(); i += 1) {
            if (_countdownOptions[i] == currentValue) {
                return _countdownOptions[(i + 1) % _countdownOptions.size()];
            }
        }
        return _countdownOptions[0];
    }

    function startCountdown() {
        _shotTimes = [];
        _splitTimes = [];
        _reloadSplits = [];
        _drawToFirstMs = null;
        _lastShotRegisteredMs = 0;
        _stats = null;
        _summaryPage = 0;
        _gpsVerifiedAtStart = false;
        _gpsAccuracyAtStart = null;
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
        _gpsVerifiedAtStart = false;
        _gpsAccuracyAtStart = null;
        stopFitRecording(false);
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
            :gpsVerifiedAtStart => _gpsVerifiedAtStart,
            :gpsAccuracyAtStartM => _gpsAccuracyAtStart,
            :gpsVerifiedAtEnd => _gpsVerified,
            :gpsAccuracyAtEndM => _gpsAccuracyMeters,
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
        var safeSession = makeStorageSafeSession(stats);
        try {
            Application.Storage.setValue("topsnipes_last_session", safeSession);
        } catch (ex) {
            System.println("Failed to save last session: " + ex.toString());
        }
    }

    function saveSessionHistory(stats) {
        var history = null;
        try {
            history = Application.Storage.getValue("topsnipes_session_history");
        } catch (ex) {
            System.println("Failed to load history: " + ex.toString());
        }
        if (history == null) {
            history = [];
        }

        // Defensive reset if an older build stored an incompatible shape.
        try {
            history.size();
        } catch (ex) {
            history = [];
        }

        history.add(makeStorageSafeSession(stats));
        while (history.size() > MAX_SESSION_HISTORY) {
            history.remove(0);
        }

        try {
            Application.Storage.setValue("topsnipes_session_history", history);
        } catch (ex) {
            System.println("Failed to save history, resetting: " + ex.toString());
            try {
                var resetHistory = [makeStorageSafeSession(stats)];
                Application.Storage.setValue("topsnipes_session_history", resetHistory);
            } catch (innerEx) {
                System.println("Failed to reset history: " + innerEx.toString());
            }
        }
    }

    function loadUserPreferences() {
        var savedIndex = Application.Storage.getValue("topsnipes_weapon_index");
        if (savedIndex == null) {
            _weaponIndex = 0;
            _sessionName = _weaponOptions[0];
        } else if (savedIndex < 0 || savedIndex >= _weaponOptions.size()) {
            _weaponIndex = 0;
            _sessionName = _weaponOptions[0];
        } else {
            _weaponIndex = savedIndex;
            _sessionName = _weaponOptions[_weaponIndex];
        }

        var savedCountdown = Application.Storage.getValue("topsnipes_countdown_seconds");
        if (savedCountdown != null && savedCountdown > 0) {
            _countdownSeconds = savedCountdown;
        }

        var savedFavorite = Application.Storage.getValue("topsnipes_favorite_weapon_index");
        if (savedFavorite != null && savedFavorite >= 0 && savedFavorite < _weaponOptions.size()) {
            _favoriteWeaponIndex = savedFavorite;
        } else {
            _favoriteWeaponIndex = _weaponIndex;
        }

        var savedUseFavorite = Application.Storage.getValue("topsnipes_use_favorite_weapon");
        if (savedUseFavorite != null) {
            _useFavoriteWeapon = savedUseFavorite;
        }

        if (_useFavoriteWeapon) {
            _weaponIndex = _favoriteWeaponIndex;
            _sessionName = _weaponOptions[_weaponIndex];
        }
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
        var centerY = h / 2;

        if (_state == STATE_SETTINGS) {
            drawSettings(dc, w, h);
            drawFooter(dc, "");
            return;
        }

        if (_state == STATE_FINISHED && _stats != null) {
            drawSummary(dc, w, h, _stats);
            drawFooter(dc, "");
            return;
        }

        drawTopGpsAcquireMessage(dc, centerX);
        drawTitle(dc, centerX);

        if (_state == STATE_COUNTDOWN) {
            var msRemaining = _countdownEndMs - System.getTimer();
            if (msRemaining <= 0) {
                _state = STATE_RUNNING;
                _sessionStartMs = System.getTimer();
                _gpsVerifiedAtStart = _gpsVerified;
                _gpsAccuracyAtStart = _gpsAccuracyMeters;
                startFitRecording();
                msRemaining = 0;
            }
            var seconds = Math.floor((msRemaining + 999) / 1000);
            dc.drawText(centerX, centerY - 66, Graphics.FONT_SMALL, "Get Ready", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, centerY - 22, Graphics.FONT_LARGE, seconds.toString(), Graphics.TEXT_JUSTIFY_CENTER);
            drawCountdownProgress(dc, w, msRemaining);
            drawFooter(dc, "");
            return;
        }

        if (_state == STATE_RUNNING) {
            var elapsed = System.getTimer() - _sessionStartMs;
            drawBigTimer(dc, centerX, centerY - 42, formatMs(elapsed));

            var shotLine = "Shots " + _shotTimes.size().toString();
            dc.drawText(centerX, h - 104, Graphics.FONT_TINY, shotLine, Graphics.TEXT_JUSTIFY_CENTER);

            var splitText = "Split --";
            if (_splitTimes.size() > 0) {
                splitText = "Last " + formatMs(_splitTimes[_splitTimes.size() - 1]);
            }
            dc.drawText(centerX, h - 88, Graphics.FONT_TINY, splitText, Graphics.TEXT_JUSTIFY_CENTER);
            var runningGpsLine = gpsBodyStatusText();
            if (runningGpsLine != "") {
                dc.drawText(centerX, h - 72, Graphics.FONT_XTINY, runningGpsLine, Graphics.TEXT_JUSTIFY_CENTER);
            }
            drawFooter(dc, "");
            return;
        }

        drawBigTimer(dc, centerX, centerY - 42, "Ready");
        dc.drawText(centerX, h - 104, Graphics.FONT_TINY, _weaponShortOptions[_weaponIndex], Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, h - 92, Graphics.FONT_XTINY, "selected", Graphics.TEXT_JUSTIFY_CENTER);
        var idleGpsLine = gpsBodyStatusText();
        if (idleGpsLine != "") {
            dc.drawText(centerX, h - 76, Graphics.FONT_XTINY, idleGpsLine, Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_weaponNoticeUntilMs > System.getTimer()) {
            dc.drawText(centerX, h - 64, Graphics.FONT_XTINY, "WEAPON UPDATED", Graphics.TEXT_JUSTIFY_CENTER);
        }
        drawFooter(dc, "");
    }

    function drawTitle(dc, x) {
        drawGpsAcquireBar(dc);
        dc.drawText(x, SAFE_TOP + 4, Graphics.FONT_MEDIUM, "Shot Timer", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawLine(26, SAFE_TOP + 16, dc.getWidth() - 26, SAFE_TOP + 16);
    }

    function drawGpsAcquireBar(dc) {
        var barX = 30;
        var barY = SAFE_TOP - 18;
        var barW = dc.getWidth() - 60;
        var barH = 8;

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(barX, barY, barW, barH, 3);

        var progress = _gpsAcquireProgress;
        if (_gpsVerified) {
            progress = 100;
        } else if (progress < 0) {
            progress = 0;
        } else if (progress > 100) {
            progress = 100;
        }

        var fillW = Math.round((barW * progress) / 100.0);
        if (fillW < 2 && progress > 0) {
            fillW = 2;
        }
        if (fillW > 0) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            dc.fillRoundedRectangle(barX, barY, fillW, barH, 3);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function drawTopGpsAcquireMessage(dc, centerX) {
        if (!_gpsMonitoring || _gpsVerified) {
            return;
        }
        if (_gpsAccuracyMeters != null) {
            return;
        }
        dc.drawText(centerX, 2, Graphics.FONT_XTINY, "gps acquiring", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawCountdownProgress(dc, width, msRemaining) {
        var barX = 36;
        var barY = dc.getHeight() - 96;
        var barW = width - 72;
        var barH = 8;
        var elapsedRatio = 1.0 - ((msRemaining * 1.0) / (_countdownSeconds * 1000.0));
        if (elapsedRatio < 0) {
            elapsedRatio = 0;
        }
        if (elapsedRatio > 1) {
            elapsedRatio = 1;
        }
        var fillW = Math.round(barW * elapsedRatio);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(barX, barY, barW, barH, 3);
        if (fillW > 0) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            dc.fillRoundedRectangle(barX, barY, fillW, barH, 3);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function drawSettings(dc, width, height) {
        var y = 36;
        dc.drawText(width / 2, y, Graphics.FONT_SMALL, "SETTINGS", Graphics.TEXT_JUSTIFY_CENTER);

        var rows = [
            "Countdown: " + _countdownSeconds.toString() + "s",
            "Weapon: " + _weaponShortOptions[_weaponIndex],
            "Favorite: " + _weaponShortOptions[_favoriteWeaponIndex],
            "Use Favorite: " + boolLabel(_useFavoriteWeapon),
            "Clear Session Logs"
        ];

        for (var i = 0; i < rows.size(); i += 1) {
            var rowY = y + 24 + (i * 22);
            var prefix = "  ";
            if (i == _settingsIndex) {
                prefix = "> ";
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
                dc.fillRoundedRectangle(18, rowY - 8, width - 36, 15, 3);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            dc.drawText(width / 2, rowY, Graphics.FONT_XTINY, trimForWatch(prefix + rows[i], 26), Graphics.TEXT_JUSTIFY_CENTER);
        }
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

    function drawBigTimer(dc, centerX, y, value) {
        dc.drawText(centerX, y, Graphics.FONT_LARGE, value, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawSummary(dc, width, height, stats) {
        var title = "SUMMARY";
        var lines = [];
        if (_summaryPage == 0) {
            title = "SUMMARY";
            lines = [
                "Weapon: " + trimForWatch(stats[:weapon], 14),
                "Shots: " + stats[:shotCount].toString(),
                "Draw: " + formatMaybe(stats[:drawToFirstMs]),
                "Avg: " + formatMaybe(stats[:avgSplitMs]),
                "Best: " + formatMaybe(stats[:bestSplitMs]),
                "Elapsed: " + formatMs(stats[:elapsedMs])
            ];
        } else if (_summaryPage == 1) {
            title = "CADENCE";
            lines = [
                "Aggressive: " + stats[:cadenceBands][:aggressive].toString(),
                "Combat: " + stats[:cadenceBands][:combat].toString(),
                "Control: " + stats[:cadenceBands][:control].toString(),
                "Transitions: " + stats[:transitionCount].toString(),
                "Burst: " + formatPercent(stats[:burstRatio]),
                "Control: " + formatPercent(stats[:controlRatio])
            ];
        } else {
            title = "READINESS";
            lines = [
                "First3: " + formatMaybe(stats[:firstThreeAvgMs]),
                "Last3: " + formatMaybe(stats[:lastThreeAvgMs]),
                "Fatigue: " + formatSigned(stats[:fatigueDeltaMs]),
                "Cadence: " + stats[:cadenceScore].toString(),
                "Execution: " + stats[:executionScore].toString(),
                "Ready: " + stats[:readinessScore].toString()
            ];
        }

        dc.drawText(width / 2, SAFE_TOP + 2, Graphics.FONT_SMALL, title + " (" + (_summaryPage + 1).toString() + "/3)", Graphics.TEXT_JUSTIFY_CENTER);
        for (var i = 0; i < lines.size(); i += 1) {
            drawSummaryLine(dc, width, i, lines[i]);
        }
    }

    function drawSummaryLine(dc, width, idx, text) {
        var y = SAFE_TOP + 28 + (idx * 16);
        dc.drawText(width / 2, y, Graphics.FONT_XTINY, trimForWatch(text, 26), Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawFooter(dc, text) {
        if (text == null || text == "") {
            return;
        }
        dc.drawText(dc.getWidth() / 2, dc.getHeight() - SAFE_BOTTOM, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function isStartStopInput(key) {
        if ((WatchUi has :KEY_START) && key == WatchUi.KEY_START) {
            return true;
        }
        return false;
    }

    function isLapInput(key) {
        if ((WatchUi has :KEY_LAP) && key == WatchUi.KEY_LAP) {
            return true;
        }
        if (key == WatchUi.KEY_ENTER) {
            return true;
        }
        if (!(WatchUi has :KEY_LAP) && key == WatchUi.KEY_ESC) {
            return true;
        }
        return false;
    }

    function isEscInput(key) {
        return key == WatchUi.KEY_ESC;
    }

    function isSummaryNextInput(key) {
        return key == WatchUi.KEY_UP;
    }

    function isSummaryPrevInput(key) {
        if (key == WatchUi.KEY_DOWN) {
            return true;
        }
        return false;
    }

    function gpsBodyStatusText() {
        if (!_gpsMonitoring) {
            return "GPS UNAVAILABLE";
        }
        if (!_gpsVerified && _gpsAccuracyMeters == null) {
            return "";
        }
        return _gpsStatusText;
    }

    function startGpsMonitoring() {
        if (_gpsMonitoring) {
            return;
        }
        _gpsVerified = false;
        _gpsStatusText = "GPS CHECKING";
        _gpsAccuracyMeters = null;
        _gpsAcquireProgress = 0;
        try {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onGpsUpdate));
            _gpsMonitoring = true;
        } catch (ex) {
            _gpsStatusText = "GPS UNAVAILABLE";
            _gpsMonitoring = false;
            System.println("GPS start failed: " + ex.toString());
        }
        WatchUi.requestUpdate();
    }

    function stopGpsMonitoring() {
        if (!_gpsMonitoring) {
            return;
        }
        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        } catch (ex) {
            System.println("GPS stop failed: " + ex.toString());
        }
        _gpsMonitoring = false;
    }

    function onGpsUpdate(info as Position.Info) as Void {
        if (info == null) {
            _gpsVerified = false;
            _gpsAccuracyMeters = null;
            _gpsStatusText = "GPS NOT VERIFIED";
            WatchUi.requestUpdate();
            return;
        }

        var accuracy = null;
        if (info has :accuracy) {
            accuracy = info.accuracy;
        }

        var hasPosition = false;
        if (info has :position) {
            hasPosition = (info.position != null);
        }

        var verified = hasPosition;
        if (accuracy != null) {
            verified = hasPosition && (accuracy <= GPS_GOOD_ACCURACY_METERS);
        }

        _gpsVerified = verified;
        _gpsAccuracyMeters = accuracy;
        if (verified) {
            _gpsAcquireProgress = 100;
        } else if (accuracy != null) {
            var estimated = 100 - Math.round((accuracy - GPS_GOOD_ACCURACY_METERS) * 1.2);
            if (estimated < 8) {
                estimated = 8;
            }
            if (estimated > 95) {
                estimated = 95;
            }
            if (estimated > _gpsAcquireProgress) {
                _gpsAcquireProgress = estimated;
            }
        }
        _gpsStatusText = buildGpsStatusText();
        WatchUi.requestUpdate();
    }

    function buildGpsStatusText() {
        if (_gpsVerified) {
            if (_gpsAccuracyMeters != null) {
                return "GPS VERIFIED (" + Math.round(_gpsAccuracyMeters).toString() + "m)";
            }
            return "GPS VERIFIED";
        }
        if (_gpsMonitoring && _gpsAccuracyMeters == null) {
            return "GPS ACQUIRING";
        }
        if (_gpsAccuracyMeters != null) {
            return "GPS NOT VERIFIED (" + Math.round(_gpsAccuracyMeters).toString() + "m)";
        }
        return "GPS NOT VERIFIED";
    }

    function makeStorageSafeSession(stats) {
        if (stats == null) {
            return null;
        }

        var cadenceBands = stats[:cadenceBands];
        if (cadenceBands == null) {
            cadenceBands = {
                :aggressive => 0,
                :combat => 0,
                :control => 0,
                :recovery => 0
            };
        }

        var safeCadenceBands = {
            "aggressive" => toSafeInt(cadenceBands[:aggressive]),
            "combat" => toSafeInt(cadenceBands[:combat]),
            "control" => toSafeInt(cadenceBands[:control]),
            "recovery" => toSafeInt(cadenceBands[:recovery])
        };

        var safeSplits = [];
        var splits = stats[:splits];
        if (splits == null) {
            splits = [];
        }
        for (var i = 0; i < splits.size(); i += 1) {
            safeSplits.add(toSafeInt(splits[i]));
        }

        var safeShots = [];
        var shots = stats[:shots];
        if (shots == null) {
            shots = [];
        }
        for (var j = 0; j < shots.size(); j += 1) {
            var shot = shots[j];
            safeShots.add({
                "num" => toSafeInt(shot[:num]),
                "elapsed" => toSafeInt(shot[:elapsed]),
                "split" => toSafeInt(shot[:split]),
                "isReload" => shot[:isReload] ? true : false,
                "phase" => toSafeString(shot[:phase], "unknown")
            });
        }

        return {
            "dataVersion" => toSafeIntWithFallback(stats[:dataVersion], APP_DATA_VERSION),
            "weapon" => toSafeString(stats[:weapon], _sessionName),
            "shotCount" => toSafeInt(stats[:shotCount]),
            "elapsedMs" => toSafeInt(stats[:elapsedMs]),
            "drawToFirstMs" => toSafeNullableInt(stats[:drawToFirstMs]),
            "gpsVerifiedAtStart" => stats[:gpsVerifiedAtStart] ? true : false,
            "gpsAccuracyAtStartM" => toSafeNullableInt(stats[:gpsAccuracyAtStartM]),
            "gpsVerifiedAtEnd" => stats[:gpsVerifiedAtEnd] ? true : false,
            "gpsAccuracyAtEndM" => toSafeNullableInt(stats[:gpsAccuracyAtEndM]),
            "avgSplitMs" => toSafeNullableInt(stats[:avgSplitMs]),
            "bestSplitMs" => toSafeNullableInt(stats[:bestSplitMs]),
            "worstSplitMs" => toSafeNullableInt(stats[:worstSplitMs]),
            "splitStdDevMs" => toSafeNullableInt(stats[:splitStdDevMs]),
            "reloadCount" => toSafeInt(stats[:reloadCount]),
            "avgReloadMs" => toSafeNullableInt(stats[:avgReloadMs]),
            "transitionCount" => toSafeInt(stats[:transitionCount]),
            "longestFastStreak" => toSafeInt(stats[:longestFastStreak]),
            "firstThreeAvgMs" => toSafeNullableInt(stats[:firstThreeAvgMs]),
            "lastThreeAvgMs" => toSafeNullableInt(stats[:lastThreeAvgMs]),
            "fatigueDeltaMs" => toSafeNullableInt(stats[:fatigueDeltaMs]),
            // Store ratios as integer percentages to keep storage primitive-safe.
            "burstRatioPct" => toSafeInt(Math.round((stats[:burstRatio] || 0) * 100)),
            "controlRatioPct" => toSafeInt(Math.round((stats[:controlRatio] || 0) * 100)),
            "cadenceScore" => toSafeInt(stats[:cadenceScore]),
            "executionScore" => toSafeInt(stats[:executionScore]),
            "readinessScore" => toSafeInt(stats[:readinessScore]),
            "cadenceBands" => safeCadenceBands,
            "splits" => safeSplits,
            "shots" => safeShots,
            "savedAtMs" => toSafeInt(System.getTimer())
        };
    }

    function toSafeInt(value) {
        return toSafeIntWithFallback(value, 0);
    }

    function toSafeIntWithFallback(value, fallback) {
        var fb = fallback;
        if (fb == null) {
            fb = 0;
        }
        if (value == null) {
            return fb;
        }
        try {
            return value.toLong();
        } catch (ex) {
            try {
                return Math.round(value).toLong();
            } catch (innerEx) {
                return fb;
            }
        }
    }

    function toSafeNullableInt(value) {
        if (value == null) {
            return null;
        }
        try {
            return value.toLong();
        } catch (ex) {
            try {
                return Math.round(value).toLong();
            } catch (innerEx) {
                return null;
            }
        }
    }

    function toSafeString(value, fallback) {
        if (value == null) {
            return fallback;
        }
        return value.toString();
    }

    function boolLabel(value) {
        if (value) {
            return "ON";
        }
        return "OFF";
    }

    function trimForWatch(text, limit) {
        if (text == null) {
            return "";
        }
        if (text.length() <= limit) {
            return text;
        }
        return text.substring(0, limit - 3) + "...";
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
