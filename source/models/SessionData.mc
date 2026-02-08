import Toybox.Math;
import Toybox.Time;

class SessionData {
    var sessionId as String;
    var weaponType as Number;
    var drillType as Number;
    var startTimerMs as Number;
    var shotTimestamps as Array<Number>;
    var splitTimes as Array<Number>;
    var totalTimeMs as Number;
    var shotCount as Number;
    var gpsLat as Number or Null;
    var gpsLon as Number or Null;
    var deviceModel as String;
    var appVersion as String;
    var createdAtEpochMs as Number;
    var synced as Boolean;
    var _fixedCapacity as Number;

    function initialize(sessionIdValue as String, weapon as Number, drill as Number, appVersionValue as String, device as String) {
        sessionId = sessionIdValue;
        weaponType = weapon;
        drillType = drill;
        startTimerMs = 0;
        shotTimestamps = [] as Array<Number>;
        splitTimes = [] as Array<Number>;
        totalTimeMs = 0;
        shotCount = 0;
        gpsLat = null;
        gpsLon = null;
        deviceModel = device;
        appVersion = appVersionValue;
        createdAtEpochMs = Time.now().value();
        synced = false;
        _fixedCapacity = 0;
    }

    function markStart(startMs as Number) as Void {
        startTimerMs = startMs;
    }

    function preallocate(maxShots as Number) as Void {
        if (maxShots <= 0) {
            _fixedCapacity = 0;
            shotTimestamps = [] as Array<Number>;
            splitTimes = [] as Array<Number>;
            shotCount = 0;
            return;
        }

        _fixedCapacity = Math.round(maxShots);
        shotTimestamps = new Array<Number>[_fixedCapacity];
        if (_fixedCapacity > 1) {
            splitTimes = new Array<Number>[_fixedCapacity - 1];
        } else {
            splitTimes = [] as Array<Number>;
        }
        shotCount = 0;
    }

    function recordShot(timestampMs as Number) as Void {
        if (_fixedCapacity > 0) {
            if (shotCount >= _fixedCapacity) {
                return;
            }
            if (shotCount > 0) {
                var fixedPrior = shotTimestamps[shotCount - 1];
                splitTimes[shotCount - 1] = timestampMs - fixedPrior;
            }
            shotTimestamps[shotCount] = timestampMs;
            shotCount += 1;
            totalTimeMs = timestampMs - startTimerMs;
            return;
        }

        if (shotCount > 0) {
            var prior = shotTimestamps[shotCount - 1];
            splitTimes.add(timestampMs - prior);
        }
        shotTimestamps.add(timestampMs);
        shotCount += 1;
        totalTimeMs = timestampMs - startTimerMs;
    }

    function setGps(lat as Number, lon as Number) as Void {
        gpsLat = lat;
        gpsLon = lon;
    }

    function finalizeSession(endMs as Number) as Void {
        if (startTimerMs <= 0) {
            totalTimeMs = 0;
            return;
        }
        if (endMs < startTimerMs) {
            totalTimeMs = 0;
            return;
        }
        totalTimeMs = endMs - startTimerMs;
    }

    function lastSplit() as Number or Null {
        if (shotCount < 2) {
            return null;
        }
        return splitTimes[shotCount - 2];
    }

    function averageSplit() as Number or Null {
        if (shotCount < 2) {
            return null;
        }

        var sum = 0;
        var splitCount = shotCount - 1;
        for (var i = 0; i < splitCount; i += 1) {
            sum += splitTimes[i];
        }
        return sum / splitCount;
    }

    function toDict() as Dictionary {
        var shots = [] as Array<Number>;
        var splits = [] as Array<Number>;
        for (var i = 0; i < shotCount; i += 1) {
            shots.add(shotTimestamps[i]);
        }
        var splitCount = shotCount - 1;
        if (splitCount < 0) {
            splitCount = 0;
        }
        for (var j = 0; j < splitCount; j += 1) {
            splits.add(splitTimes[j]);
        }

        var payload = {
            "sessionId" => sessionId,
            "weaponType" => weaponType,
            "drillType" => drillType,
            "startTimerMs" => startTimerMs,
            "shotTimestamps" => shots,
            "splitTimes" => splits,
            "totalTimeMs" => totalTimeMs,
            "shotCount" => shotCount,
            "deviceModel" => deviceModel,
            "appVersion" => appVersion,
            "createdAtEpochMs" => createdAtEpochMs,
            "synced" => synced
        };

        if (gpsLat != null) {
            payload["gpsLat"] = gpsLat;
        }
        if (gpsLon != null) {
            payload["gpsLon"] = gpsLon;
        }
        return payload;
    }

    function cloneForStorage() as Dictionary {
        var shots = [] as Array<Number>;
        var splits = [] as Array<Number>;

        for (var i = 0; i < shotCount; i += 1) {
            shots.add(Math.round(shotTimestamps[i]));
        }
        var splitCount = shotCount - 1;
        if (splitCount < 0) {
            splitCount = 0;
        }
        for (var j = 0; j < splitCount; j += 1) {
            splits.add(Math.round(splitTimes[j]));
        }

        var payload = {
            "sessionId" => sessionId,
            "weaponType" => Math.round(weaponType),
            "drillType" => Math.round(drillType),
            "startTimerMs" => Math.round(startTimerMs),
            "shotTimestamps" => shots,
            "splitTimes" => splits,
            "totalTimeMs" => Math.round(totalTimeMs),
            "shotCount" => Math.round(shotCount),
            "deviceModel" => deviceModel,
            "appVersion" => appVersion,
            "createdAtEpochMs" => Math.round(createdAtEpochMs),
            "synced" => synced
        };

        // Storage-safe GPS encoding: integer micro-degrees avoids Float writes.
        if (gpsLat != null) {
            payload["gpsLatE6"] = Math.round(gpsLat * 1000000);
        }
        if (gpsLon != null) {
            payload["gpsLonE6"] = Math.round(gpsLon * 1000000);
        }
        return payload;
    }
}
