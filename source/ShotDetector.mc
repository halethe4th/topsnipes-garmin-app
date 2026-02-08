import Toybox.Sensor;
import Toybox.System;

class ShotDetector {
    var _onShot as Method;
    var _active as Boolean;
    var _debounceMs as Number;
    var _sensitivity as Number;
    var _lastShotTs as Number;
    var _baselinePower as Number;
    var _thresholdPower as Number;
    var _calibrationEndTs as Number;

    function initialize(onShotHandler as Method) {
        _onShot = onShotHandler;
        _active = false;
        _debounceMs = Constants.DEFAULT_DEBOUNCE_MS;
        _sensitivity = Constants.DEFAULT_SENSITIVITY;
        _lastShotTs = 0;
        _baselinePower = 1000;
        _thresholdPower = Constants.SHOT_POWER_MIN;
        _calibrationEndTs = 0;
    }

    function start(sensitivity as Number, debounceMs as Number) as Void {
        _active = true;
        _sensitivity = sensitivity;
        _debounceMs = debounceMs;
        _lastShotTs = 0;
        _baselinePower = 1000;
        _thresholdPower = Constants.SHOT_POWER_MIN;
        _calibrationEndTs = System.getTimer() + 2000;

        if (Sensor has :registerSensorDataListener) {
            var options = {
                :period => 1,
                :accelerometer => {
                    :enabled => true,
                    :sampleRate => 100,
                    :includePower => true,
                    :includeTimestamps => true
                }
            };

            try {
                Sensor.registerSensorDataListener(method(:onSensorData), options);
            } catch (ex) {
                LogUtils.debug("ShotDetector register failed");
            }
        }
    }

    function stop() as Void {
        _active = false;
        if (Sensor has :unregisterSensorDataListener) {
            try {
                Sensor.unregisterSensorDataListener();
            } catch (ex) {
                LogUtils.debug("ShotDetector unregister failed");
            }
        }
    }

    function isActive() as Boolean {
        return _active;
    }

    function onSensorData(data as Sensor.SensorData) as Void {
        if (!_active || data == null) {
            return;
        }

        var accel = data.accelerometerData;
        if (accel == null || accel.power == null) {
            return;
        }

        var powerArray = accel.power;
        var tsArray = null;
        if (accel has :timestamp) {
            tsArray = accel.timestamp;
        }

        for (var i = 0; i < powerArray.size(); i += 1) {
            var samplePower = powerArray[i];
            var sampleTs = System.getTimer();
            if (tsArray != null && i < tsArray.size()) {
                sampleTs = tsArray[i];
            }
            processSample(samplePower, sampleTs);
        }
    }

    function processSample(power as Number, timestampMs as Number) as Void {
        if (!_active) {
            return;
        }

        var now = System.getTimer();
        if (now <= _calibrationEndTs) {
            _baselinePower = ((_baselinePower * 9) + power) / 10;
            _thresholdPower = computeThreshold(_baselinePower, _sensitivity);
            return;
        }

        if ((timestampMs - _lastShotTs) < _debounceMs) {
            return;
        }

        if (power >= _thresholdPower) {
            _lastShotTs = timestampMs;
            _onShot.invoke(timestampMs, power);
        }
    }

    hidden function computeThreshold(basePower as Number, sensitivity as Number) as Number {
        var normalized = DeviceUtils.clamp(sensitivity, 1, 10);
        var dynamicOffset = (11 - normalized) * 420;
        var threshold = basePower + dynamicOffset;

        if (threshold < Constants.SHOT_POWER_MIN) {
            threshold = Constants.SHOT_POWER_MIN;
        }
        if (threshold > Constants.SHOT_POWER_MAX) {
            threshold = Constants.SHOT_POWER_MAX;
        }
        return threshold;
    }
}
