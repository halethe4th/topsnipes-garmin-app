import Toybox.Communications;
import Toybox.Timer;

class SyncManager {
    var _storage as StorageManager;
    var _syncing as Boolean;
    var _currentSessionId as String or Null;
    var _status as String;
    var _retryCount as Number;
    var _retryTimer as Timer.Timer;

    function initialize(storage as StorageManager) {
        _storage = storage;
        _syncing = false;
        _currentSessionId = null;
        _status = "idle";
        _retryCount = 0;
        _retryTimer = new Timer.Timer();
    }

    function statusText() as String {
        return _status;
    }

    function isSyncing() as Boolean {
        return _syncing;
    }

    function pendingCount() as Number {
        return _storage.pendingSyncIds().size();
    }

    function checkPendingSyncs() as Void {
        if (_syncing) {
            return;
        }
        var pending = _storage.pendingSyncIds();
        if (pending.size() == 0) {
            _status = "all synced";
            return;
        }
        _status = "pending " + pending.size().toString();
        syncNextPending();
    }

    function requestSyncNow() as Void {
        _retryCount = 0;
        checkPendingSyncs();
    }

    function syncNextPending() as Void {
        if (_syncing) {
            return;
        }

        var pending = _storage.pendingSyncIds();
        if (pending.size() == 0) {
            _status = "all synced";
            _currentSessionId = null;
            return;
        }

        var sessionId = pending[0];
        var session = _storage.sessionById(sessionId);
        if (session == null) {
            _storage.markSynced(sessionId);
            syncNextPending();
            return;
        }

        _currentSessionId = sessionId;
        _syncing = true;
        var statusId = sessionId;
        if (sessionId.length() > 6) {
            statusId = sessionId.substring(0, 6);
        }
        _status = "syncing " + statusId;

        var params = session.toDict();
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => "application/json",
                "X-TopSnipes-Device" => "garmin"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        try {
            Communications.makeWebRequest(Constants.CLOUD_UPLOAD_URL, params, options, method(:onSyncResponse));
        } catch (ex) {
            _syncing = false;
            _status = "sync error";
            scheduleRetry();
        }
    }

    function onSyncResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        _syncing = false;

        if (_currentSessionId == null) {
            return;
        }

        if (responseCode == 200) {
            _storage.markSynced(_currentSessionId);
            _status = "synced";
            _retryCount = 0;
            _currentSessionId = null;
            syncNextPending();
            return;
        }

        if (responseCode == -104) {
            _status = "phone disconnected";
            return;
        }

        _status = "sync failed " + responseCode.toString();
        scheduleRetry();
    }

    hidden function scheduleRetry() as Void {
        _retryCount += 1;
        if (_retryCount > 5) {
            _status = "retry paused";
            _retryCount = 0;
            return;
        }

        var delaySec = _retryCount * 8;
        _retryTimer.stop();
        _retryTimer.start(method(:retryTimerFired), delaySec * 1000, false);
    }

    function retryTimerFired() as Void {
        if (_syncing) {
            return;
        }
        syncNextPending();
    }
}
