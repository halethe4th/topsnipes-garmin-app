import Toybox.Application;
import Toybox.System;

class StorageManager {
    function initialize() {
    }

    function saveSession(session as SessionData) as Boolean {
        var sessionDict = session.cloneForStorage();
        var key = session.sessionId;

        if (!safeSetValue(key, sessionDict)) {
            return false;
        }

        var ids = getSessionIds();
        ids.add(key);
        ids = uniqueIds(ids);
        while (ids.size() > Constants.MAX_HISTORY) {
            var removeId = ids[0];
            ids.remove(0);
            safeDeleteValue(removeId);
        }
        safeSetValue(Constants.STORAGE_SESSION_IDS, ids);

        queuePendingSync(key);
        return true;
    }

    function saveActiveSessionSnapshot(session as SessionData or Null) as Void {
        if (session == null) {
            safeDeleteValue(Constants.STORAGE_ACTIVE_SESSION);
            return;
        }
        safeSetValue(Constants.STORAGE_ACTIVE_SESSION, session.cloneForStorage());
    }

    function loadActiveSessionSnapshot() as SessionData or Null {
        var data = safeGetValue(Constants.STORAGE_ACTIVE_SESSION);
        if (!(data instanceof Dictionary)) {
            return null;
        }
        return fromStoredDict(data);
    }

    function clearActiveSessionSnapshot() as Void {
        safeDeleteValue(Constants.STORAGE_ACTIVE_SESSION);
    }

    function sessionById(sessionId as String) as SessionData or Null {
        var dict = safeGetValue(sessionId);
        if (!(dict instanceof Dictionary)) {
            return null;
        }
        return fromStoredDict(dict);
    }

    function recentSessions(limit as Number) as Array<SessionData> {
        var results = [] as Array<SessionData>;
        var ids = getSessionIds();

        var added = 0;
        for (var i = ids.size() - 1; i >= 0; i -= 1) {
            if (added >= limit) {
                break;
            }
            var session = sessionById(ids[i]);
            if (session != null) {
                results.add(session);
                added += 1;
            }
        }
        return results;
    }

    function queuePendingSync(sessionId as String) as Void {
        var pending = pendingSyncIds();
        pending.add(sessionId);
        pending = uniqueIds(pending);
        safeSetValue(Constants.STORAGE_PENDING_SYNC, pending);
    }

    function pendingSyncIds() as Array<String> {
        var value = safeGetValue(Constants.STORAGE_PENDING_SYNC);
        if (!(value instanceof Array)) {
            return [] as Array<String>;
        }

        var pending = [] as Array<String>;
        for (var i = 0; i < value.size(); i += 1) {
            pending.add(value[i].toString());
        }
        return pending;
    }

    function markSynced(sessionId as String) as Void {
        var session = sessionById(sessionId);
        if (session != null) {
            session.synced = true;
            safeSetValue(sessionId, session.cloneForStorage());
        }

        var pending = pendingSyncIds();
        var filtered = [] as Array<String>;
        for (var i = 0; i < pending.size(); i += 1) {
            if (pending[i] != sessionId) {
                filtered.add(pending[i]);
            }
        }
        safeSetValue(Constants.STORAGE_PENDING_SYNC, filtered);
    }

    function safeGetValue(key as String) as Object or Null {
        try {
            return Application.Storage.getValue(key);
        } catch (ex) {
            System.println("Storage read failed: " + key + " => " + ex.toString());
            return null;
        }
    }

    function safeSetValue(key as String, value as Object or Null) as Boolean {
        try {
            Application.Storage.setValue(key, value);
            return true;
        } catch (ex) {
            System.println("Storage write failed: " + key + " => " + ex.toString());
            return false;
        }
    }

    function safeDeleteValue(key as String) as Void {
        try {
            Application.Storage.deleteValue(key);
        } catch (ex) {
            System.println("Storage delete failed: " + key + " => " + ex.toString());
        }
    }

    hidden function getSessionIds() as Array<String> {
        var value = safeGetValue(Constants.STORAGE_SESSION_IDS);
        if (!(value instanceof Array)) {
            return [] as Array<String>;
        }

        var ids = [] as Array<String>;
        for (var i = 0; i < value.size(); i += 1) {
            ids.add(value[i].toString());
        }
        return ids;
    }

    hidden function uniqueIds(values as Array<String>) as Array<String> {
        var uniques = [] as Array<String>;
        for (var i = 0; i < values.size(); i += 1) {
            var candidate = values[i];
            var seen = false;
            for (var j = 0; j < uniques.size(); j += 1) {
                if (uniques[j] == candidate) {
                    seen = true;
                    break;
                }
            }
            if (!seen) {
                uniques.add(candidate);
            }
        }
        return uniques;
    }

    hidden function toNumber(value as Object or Null, fallback as Number) as Number {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Number) {
            return value as Number;
        }
        if (value instanceof Boolean) {
            return (value as Boolean) ? 1 : 0;
        }
        if (value instanceof String) {
            try {
                return (value as String).toNumber();
            } catch (ex) {
                return fallback;
            }
        }
        return fallback;
    }

    hidden function toGpsCoordinate(value as Object or Null) as Number or Null {
        if (value == null) {
            return null;
        }
        if (value instanceof Number) {
            return (value as Number) / 1000000;
        }
        return null;
    }

    hidden function fromStoredDict(dict as Dictionary) as SessionData or Null {
        var sessionId = dict["sessionId"];
        if (sessionId == null) {
            return null;
        }

        var weaponType = toNumber(dict["weaponType"], Constants.WeaponType.WEAPON_HANDGUN);
        var drillType = toNumber(dict["drillType"], Constants.DrillType.DRILL_FREESTYLE);
        var appVersion = "1.0.0";
        if (dict["appVersion"] != null) {
            appVersion = dict["appVersion"].toString();
        }

        var device = "unknown-device";
        if (dict["deviceModel"] != null) {
            device = dict["deviceModel"].toString();
        }

        var session = new SessionData(sessionId.toString(), weaponType, drillType, appVersion, device);
        session.startTimerMs = toNumber(dict["startTimerMs"], 0);
        session.totalTimeMs = toNumber(dict["totalTimeMs"], 0);
        session.shotCount = toNumber(dict["shotCount"], 0);
        session.createdAtEpochMs = toNumber(dict["createdAtEpochMs"], 0);
        session.synced = dict["synced"] == true;
        session.gpsLat = toGpsCoordinate(dict["gpsLatE6"]);
        session.gpsLon = toGpsCoordinate(dict["gpsLonE6"]);
        if (session.gpsLat == null && dict["gpsLat"] != null && dict["gpsLat"] instanceof Number) {
            session.gpsLat = dict["gpsLat"] as Number;
        }
        if (session.gpsLon == null && dict["gpsLon"] != null && dict["gpsLon"] instanceof Number) {
            session.gpsLon = dict["gpsLon"] as Number;
        }

        session.shotTimestamps = [] as Array<Number>;
        if (dict["shotTimestamps"] instanceof Array) {
            var shots = dict["shotTimestamps"] as Array;
            for (var i = 0; i < shots.size(); i += 1) {
                session.shotTimestamps.add(toNumber(shots[i], 0));
            }
        }

        session.splitTimes = [] as Array<Number>;
        if (dict["splitTimes"] instanceof Array) {
            var splits = dict["splitTimes"] as Array;
            for (var j = 0; j < splits.size(); j += 1) {
                session.splitTimes.add(toNumber(splits[j], 0));
            }
        }

        session.shotCount = session.shotTimestamps.size();
        return session;
    }
}
