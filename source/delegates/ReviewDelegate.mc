import Toybox.WatchUi;

class ReviewDelegate extends WatchUi.BehaviorDelegate {
    var _view as ReviewView;

    function initialize(view as ReviewView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Boolean {
        var manager = AppContext.sessionManager();
        if (manager != null && manager.state() == Constants.SessionState.STATE_COMPLETE) {
            manager.resetToIdle();
            var menuView = new MainMenuView();
            WatchUi.switchToView(menuView, new MainMenuDelegate(menuView), WatchUi.SLIDE_RIGHT);
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onNextPage() as Boolean {
        _view.scroll(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scroll(-1);
        return true;
    }

    function onSelect() as Boolean {
        var sync = AppContext.syncManager();
        if (sync != null) {
            sync.requestSyncNow();
        }
        return true;
    }
}
