module AppContext {
    var _sessionManager as SessionManager or Null;
    var _storageManager as StorageManager or Null;
    var _syncManager as SyncManager or Null;

    function initialize(sessionManager as SessionManager, storageManager as StorageManager, syncManager as SyncManager) as Void {
        _sessionManager = sessionManager;
        _storageManager = storageManager;
        _syncManager = syncManager;
    }

    function sessionManager() as SessionManager or Null {
        return _sessionManager;
    }

    function storageManager() as StorageManager or Null {
        return _storageManager;
    }

    function syncManager() as SyncManager or Null {
        return _syncManager;
    }
}
