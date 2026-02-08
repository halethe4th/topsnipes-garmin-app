import Toybox.Application;
import Toybox.Sensor;
import Toybox.WatchUi;

class TopSnipesApp extends Application.AppBase {
    var _storage as StorageManager;
    var _sessionManager as SessionManager;
    var _syncManager as SyncManager;

    function initialize() {
        AppBase.initialize();

        _storage = new StorageManager();
        _sessionManager = new SessionManager(_storage);
        _syncManager = new SyncManager(_storage);

        AppContext.initialize(_sessionManager, _storage, _syncManager);
    }

    function onStart(state as Dictionary or Null) as Void {
        _sessionManager.restoreActiveSessionIfAny();
        _syncManager.checkPendingSyncs();
    }

    function onStop(state as Dictionary or Null) as Void {
        if (Sensor has :unregisterSensorDataListener) {
            try {
                Sensor.unregisterSensorDataListener();
            } catch (ex) {
                // no-op
            }
        }
        _sessionManager.saveActiveSession();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new MainMenuView();
        var delegate = new MainMenuDelegate(view);
        return [view, delegate];
    }

    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new TopSnipesGlanceView()];
    }

    function getSettingsView() as [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return null;
    }
}
