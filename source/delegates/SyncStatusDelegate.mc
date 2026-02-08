import Toybox.WatchUi;

class SyncStatusDelegate extends WatchUi.BehaviorDelegate {
    var _view as SyncStatusView;

    function initialize(view as SyncStatusView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSelect() as Boolean {
        var sync = AppContext.syncManager();
        if (sync != null) {
            sync.requestSyncNow();
        }
        WatchUi.requestUpdate();
        return true;
    }
}
