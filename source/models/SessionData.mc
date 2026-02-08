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

    function initialize(sessionIdValue as String, weapon as Number, drill as Number, appVersionValue as String, device as String) {
        sessionId = sessionIdValue;
        weaponType = weapon;
        drillType = drill;
        startTimerMs = 0;
        shotTimestamps = [];
        splitTimes = [];
        totalTimeMs = 0;
        shotCount = 0;
        gpsLat = null;
        gpsLon = null;
        deviceModel = device;
        appVersion = appVersionValue;
        createdAtEpochMs = Time.now().value();
        synced = false;
    }

    function markStart(startMs as Number) as Void {
        startTimerMs = startMs;
    }

    function recordShot(timestampMs as Number) as Void {
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
        if (shotCount > 0) {
            totalTimeMs = endMs - startTimerMs;
        }
    }

    function lastSplit() as Number or Null {
        if (splitTimes.size() == 0) {
            return null;
        }
        return splitTimes[splitTimes.size() - 1];
    }

    function averageSplit() as Number or Null {
        if (splitTimes.size() == 0) {
            return null;
        }

        var sum = 0;
        for (var i = 0; i < splitTimes.size(); i += 1) {
            sum += splitTimes[i];
        }
        return sum / splitTimes.size();
    }

    function toDict() as Dictionary {
        var payload = {
            "sessionId" => sessionId,
            "weaponType" => weaponType,
            "drillType" => drillType,
            "startTimerMs" => startTimerMs,
            "shotTimestamps" => shotTimestamps,
            "splitTimes" => splitTimes,
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

        for (var i = 0; i < shotTimestamps.size(); i += 1) {
            shots.add(Math.round(shotTimestamps[i]));
        }
        for (var j = 0; j < splitTimes.size(); j += 1) {
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
