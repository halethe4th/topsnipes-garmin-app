import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Application;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Lang;


class SessionManager {
    var _storage as StorageManager;
    var _timer as TimerEngine;
    var _detector as ShotDetector;

    var _state as Number;
    var _session as SessionData or Null;
    var _countdownSeconds as Number;
    var _maxShots as Number;
    var _autoStop as Boolean;
    var _hapticOnShot as Boolean;
    var _hapticOnStart as Boolean;
    var _sensitivity as Number;
    var _debounceMs as Number;

    var _fitSession as ActivityRecording.Session or Null;
    var _fitShotCountField as FitContributor.Field or Null;
    var _fitAvgSplitField as FitContributor.Field or Null;
    var _fitGpsVerifiedField as FitContributor.Field or Null;
    var _gpsRequestedAt as Number;
    var _gpsActive as Boolean;
    var _gpsVerified as Boolean;
    var _gpsProgressPct as Number;
    var _gpsStatus as String;
    var _lastCountdownSecond as Number;

    function initialize(storage as StorageManager) {
        _storage = storage;
        _timer = new TimerEngine();
        _detector = new ShotDetector(method(:onDetectedShot));

        _state = Constants.SessionState.STATE_IDLE;
        _session = null;
        _countdownSeconds = Constants.DEFAULT_COUNTDOWN_SECONDS;
        _maxShots = Constants.DEFAULT_MAX_SHOTS;
        _autoStop = true;
        _hapticOnShot = true;
        _hapticOnStart = true;
        _sensitivity = Constants.DEFAULT_SENSITIVITY;
        _debounceMs = Constants.DEFAULT_DEBOUNCE_MS;

        _fitSession = null;
        _fitShotCountField = null;
        _fitAvgSplitField = null;
        _fitGpsVerifiedField = null;
        _gpsRequestedAt = 0;
        _gpsActive = false;
        _gpsVerified = false;
        _gpsProgressPct = 0;
        _gpsStatus = Rez.Strings.GpsStatusOff;
        _lastCountdownSecond = -1;

        loadUserSettings();
    }

    function state() as Number {
        return _state;
    }

    function activeSession() as SessionData or Null {
        return _session;
    }

    function hasActiveSession() as Boolean {
        return _session != null && (
            _state == Constants.SessionState.STATE_READY ||
            _state == Constants.SessionState.STATE_COUNTDOWN ||
            _state == Constants.SessionState.STATE_LISTENING
        );
    }

    function beginNewSession(weaponType as Number, drillType as Number, maxShots as Number) as Void {
        var sessionId = generateSessionId();
        var deviceLabel = DeviceUtils.deviceLabel();

        _session = new SessionData(sessionId, weaponType, drillType, Constants.APP_VERSION, deviceLabel);
        _maxShots = maxShots;
        if (_maxShots < 0) {
            _maxShots = 0;
        }
        if (_maxShots > 0) {
            _session.preallocate(_maxShots);
        }
        _state = Constants.SessionState.STATE_READY;
        resetGpsState();
        beginGpsFix();

        _storage.saveActiveSessionSnapshot(_session);
    }

    function restoreActiveSessionIfAny() as Boolean {
        var snapshot = _storage.loadActiveSessionSnapshot();
        if (snapshot == null) {
            return false;
        }
        _session = snapshot;
        _state = Constants.SessionState.STATE_READY;
        _gpsVerified = snapshot.gpsLat != null && snapshot.gpsLon != null;
        _gpsStatus = Rez.Strings.GpsStatusAcquiring;
        _gpsProgressPct = 0;
        if (_gpsVerified) {
            _gpsStatus = Rez.Strings.GpsStatusVerified;
            _gpsProgressPct = 100;
        }
        if (!_gpsVerified) {
            beginGpsFix();
        }
        return true;
    }

    function startCountdown() as Void {
        if (_session == null) {
            return;
        }
        _timer.setCountdownSeconds(_countdownSeconds);
        _timer.startCountdown();
        _lastCountdownSecond = -1;
        _state = Constants.SessionState.STATE_COUNTDOWN;
        _storage.saveActiveSessionSnapshot(_session);
    }

    function cancelCountdown() as Void {
        if (_state != Constants.SessionState.STATE_COUNTDOWN) {
            return;
        }
        _timer.cancelCountdown();
        _lastCountdownSecond = -1;
        _state = Constants.SessionState.STATE_READY;
        if (_session != null) {
            _storage.saveActiveSessionSnapshot(_session);
        }
    }

    function updateState() as Void {
        updateGpsStatus();

        if (_state != Constants.SessionState.STATE_COUNTDOWN) {
            return;
        }

        if (_timer.countdownRemainingMs() > 0) {
            var remainingSec = _timer.countdownSecondsRemaining();
            if (remainingSec != _lastCountdownSecond) {
                _lastCountdownSecond = remainingSec;
                if (remainingSec > 0) {
                    vibrateCountdownTick();
                }
            }
            return;
        }

        if (_session == null) {
            _state = Constants.SessionState.STATE_IDLE;
            return;
        }

        var startMs = _timer.beginSessionNow();
        _session.markStart(startMs);

        startFitRecording();
        _detector.start(_sensitivity, _debounceMs);
        if (_hapticOnStart) {
            vibrateStart();
        }
        _state = Constants.SessionState.STATE_LISTENING;
        _storage.saveActiveSessionSnapshot(_session);
    }

    function countdownRemainingMs() as Number {
        return _timer.countdownRemainingMs();
    }

    function elapsedMs() as Number {
        if (_state == Constants.SessionState.STATE_LISTENING && _session != null) {
            return _timer.elapsedMs();
        }
        if (_session != null) {
            return _session.totalTimeMs;
        }
        return 0;
    }

    function gpsProgressPercent() as Number {
        return _gpsProgressPct;
    }

    function gpsStatusLabel() as String {
        return _gpsStatus;
    }

    function gpsIsVerified() as Boolean {
        return _gpsVerified;
    }

    function recordManualShot() as Void {
        if (_state != Constants.SessionState.STATE_LISTENING || _session == null) {
            return;
        }

        var now = _timer.nowMs();
        // Manual shot input uses same engine as sensor callbacks.
        onDetectedShot(now, 0);
    }

    function onDetectedShot(timestampMs as Number, power as Number) as Void {
        if (_state != Constants.SessionState.STATE_LISTENING || _session == null) {
            return;
        }

        _session.recordShot(timestampMs);
        if (_hapticOnShot) {
            vibrateShot();
        }

        if (_maxShots > 0 && _session.shotCount >= _maxShots && _autoStop) {
            stopSession();
            return;
        }

        _storage.saveActiveSessionSnapshot(_session);
    }

    function stopSession() as Void {
        if (_session == null) {
            _state = Constants.SessionState.STATE_IDLE;
            return;
        }

        var endMs = _timer.nowMs();
        _session.finalizeSession(endMs);

        _detector.stop();
        finishGpsFix();
        stopFitRecording();

        _storage.saveSession(_session);
        _storage.clearActiveSessionSnapshot();

        vibrateSessionEnd();
        _state = Constants.SessionState.STATE_COMPLETE;
    }

    function resetToIdle() as Void {
        _detector.stop();
        finishGpsFix();
        stopFitRecording();
        resetGpsState();
        _session = null;
        _state = Constants.SessionState.STATE_IDLE;
        _storage.clearActiveSessionSnapshot();
    }

    function saveActiveSession() as Void {
        if (_session == null) {
            _storage.clearActiveSessionSnapshot();
            return;
        }

        if (_state == Constants.SessionState.STATE_LISTENING || _state == Constants.SessionState.STATE_COUNTDOWN || _state == Constants.SessionState.STATE_READY) {
            _storage.saveActiveSessionSnapshot(_session);
        }
    }

    function loadUserSettings() as Void {
        _countdownSeconds = readNumberProperty("countdownSecs", Constants.DEFAULT_COUNTDOWN_SECONDS);
        _debounceMs = readNumberProperty("debounceMs", Constants.DEFAULT_DEBOUNCE_MS);
        _sensitivity = readNumberProperty("sensitivity", Constants.DEFAULT_SENSITIVITY);
        _maxShots = readNumberProperty("maxShots", Constants.DEFAULT_MAX_SHOTS);
        _autoStop = readBoolProperty("autoStopEnabled", true);
        _hapticOnShot = readBoolProperty("hapticOnShot", true);
        _hapticOnStart = readBoolProperty("hapticOnStart", true);

        _countdownSeconds = DeviceUtils.clamp(_countdownSeconds, 1, 30);
        _debounceMs = DeviceUtils.clamp(_debounceMs, 50, 600);
        _sensitivity = DeviceUtils.clamp(_sensitivity, 1, 10);
        _maxShots = DeviceUtils.clamp(_maxShots, 0, Constants.MAX_SHOTS_LIMIT);
    }

    hidden function readNumberProperty(key as String, fallback as Number) as Number {
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

    hidden function readBoolProperty(key as String, fallback as Boolean) as Boolean {
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
            return value == true;
        } catch (ex) {
            return fallback;
        }
    }

    hidden function generateSessionId() as String {
        return "ts-" + Time.now().value().toString() + "-" + System.getTimer().toString();
    }

    hidden function beginGpsFix() as Void {
        if (!(Position has :enableLocationEvents)) {
            _gpsStatus = Rez.Strings.GpsStatusUnsupported;
            return;
        }
        if (_session == null || _gpsVerified || _gpsActive) {
            return;
        }

        _gpsRequestedAt = System.getTimer();
        _gpsActive = true;
        _gpsProgressPct = 0;
        _gpsStatus = Rez.Strings.GpsStatusAcquiring;
        try {
            Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onGpsResult));
        } catch (ex) {
            _gpsActive = false;
            _gpsStatus = Rez.Strings.GpsStatusUnavailable;
        }
    }

    hidden function onGpsResult(info as Position.Info) as Void {
        _gpsActive = false;
        if (_session == null || !(info has :position) || info.position == null) {
            _gpsStatus = Rez.Strings.GpsStatusUnavailable;
            return;
        }

        try {
            var latlon = info.position.toDegrees();
            _session.setGps(latlon[0], latlon[1]);
            _gpsVerified = true;
            _gpsProgressPct = 100;
            _gpsStatus = Rez.Strings.GpsStatusVerified;
            _storage.saveActiveSessionSnapshot(_session);
        } catch (ex) {
            _gpsStatus = Rez.Strings.GpsStatusUnavailable;
        }
    }

    hidden function finishGpsFix() as Void {
        _gpsActive = false;
    }

    hidden function startFitRecording() as Void {
        if (!(ActivityRecording has :createSession)) {
            return;
        }

        try {
            var sportType = Activity.SPORT_GENERIC;
            if (Activity has :SPORT_SHOOTING) {
                sportType = Activity.SPORT_SHOOTING;
            }
            if (Activity has :SUB_SPORT_GENERIC) {
                _fitSession = ActivityRecording.createSession({
                    :name => "TopSnipes Session",
                    :sport => sportType,
                    :subSport => Activity.SUB_SPORT_GENERIC
                });
            } else {
                _fitSession = ActivityRecording.createSession({
                    :name => "TopSnipes Session",
                    :sport => sportType
                });
            }
            setupFitFields();
            _fitSession.start();
        } catch (ex) {
            _fitSession = null;
            _fitShotCountField = null;
            _fitAvgSplitField = null;
            _fitGpsVerifiedField = null;
        }
    }

    hidden function stopFitRecording() as Void {
        if (_fitSession == null) {
            return;
        }

        try {
            if (_fitShotCountField != null && _session != null) {
                _fitShotCountField.setData(Math.round(_session.shotCount));
            }
            if (_fitAvgSplitField != null && _session != null) {
                var avgSplitMs = _session.averageSplit();
                if (avgSplitMs == null) {
                    _fitAvgSplitField.setData(0.0);
                } else {
                    _fitAvgSplitField.setData(avgSplitMs / 1000.0);
                }
            }
            if (_fitGpsVerifiedField != null) {
                _fitGpsVerifiedField.setData(_gpsVerified ? 1 : 0);
            }
            _fitSession.stop();
            _fitSession.save();
        } catch (ex) {
            // no-op
        }
        _fitSession = null;
        _fitShotCountField = null;
        _fitAvgSplitField = null;
        _fitGpsVerifiedField = null;
    }

    hidden function vibrateShot() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(80, 100)]);
        }
    }

    hidden function vibrateStart() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 500)]);
        }
    }

    hidden function vibrateCountdownTick() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(40, 120)]);
        }
    }

    hidden function vibrateSessionEnd() as Void {
        if (!(Attention has :vibrate)) {
            return;
        }
        Attention.vibrate([
            new Attention.VibeProfile(80, 180),
            new Attention.VibeProfile(0, 80),
            new Attention.VibeProfile(80, 180),
            new Attention.VibeProfile(0, 80),
            new Attention.VibeProfile(80, 300)
        ]);
    }

    hidden function updateGpsStatus() as Void {
        if (_gpsVerified || !_gpsActive) {
            return;
        }

        var elapsed = System.getTimer() - _gpsRequestedAt;
        if (elapsed >= Constants.GPS_TIMEOUT_MS) {
            _gpsActive = false;
            _gpsProgressPct = 0;
            _gpsStatus = Rez.Strings.GpsStatusTimeout;
            return;
        }

        var pct = Math.floor((elapsed * 100) / Constants.GPS_TIMEOUT_MS);
        _gpsProgressPct = DeviceUtils.clamp(pct, 0, 95);
        _gpsStatus = Rez.Strings.GpsStatusAcquiring;
    }

    hidden function resetGpsState() as Void {
        _gpsRequestedAt = 0;
        _gpsActive = false;
        _gpsVerified = false;
        _gpsProgressPct = 0;
        _gpsStatus = Rez.Strings.GpsStatusOff;
    }

    hidden function setupFitFields() as Void {
        if (_fitSession == null || !(_fitSession has :createField)) {
            _fitShotCountField = null;
            _fitAvgSplitField = null;
            _fitGpsVerifiedField = null;
            return;
        }

        try {
            _fitShotCountField = _fitSession.createField(
                "shot_count",
                0,
                FitContributor.DATA_TYPE_UINT16,
                {
                    :mesgType => FitContributor.MESG_TYPE_SESSION,
                    :units => "shots"
                }
            );
            _fitAvgSplitField = _fitSession.createField(
                "avg_split",
                1,
                FitContributor.DATA_TYPE_FLOAT,
                {
                    :mesgType => FitContributor.MESG_TYPE_SESSION,
                    :units => "sec"
                }
            );
            _fitGpsVerifiedField = _fitSession.createField(
                "gps_verified",
                2,
                FitContributor.DATA_TYPE_UINT16,
                {
                    :mesgType => FitContributor.MESG_TYPE_SESSION,
                    :units => "bool"
                }
            );
        } catch (ex) {
            _fitShotCountField = null;
            _fitAvgSplitField = null;
            _fitGpsVerifiedField = null;
        }
    }
}
