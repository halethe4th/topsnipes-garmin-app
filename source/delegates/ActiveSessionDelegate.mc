import Toybox.WatchUi;

class ActiveSessionDelegate extends WatchUi.BehaviorDelegate {
    var _view as ActiveSessionView;

    function initialize(view as ActiveSessionView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        var manager = AppContext.sessionManager();
        if (manager == null) {
            return true;
        }

        var state = manager.state();
        if (state == Constants.SessionState.STATE_READY) {
            manager.startCountdown();
            return true;
        }
        if (state == Constants.SessionState.STATE_COUNTDOWN || state == Constants.SessionState.STATE_LISTENING) {
            manager.stopSession();
            openReview();
            return true;
        }
        if (state == Constants.SessionState.STATE_COMPLETE) {
            openReview();
            return true;
        }
        return true;
    }

    function onBack() as Boolean {
        var manager = AppContext.sessionManager();
        if (manager == null) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }

        var state = manager.state();
        // On many devices BACK maps to LAP. Treat back as split while live.
        if (state == Constants.SessionState.STATE_LISTENING) {
            manager.recordManualShot();
            return true;
        }

        if (state == Constants.SessionState.STATE_COUNTDOWN) {
            return true;
        }

        if (state == Constants.SessionState.STATE_COMPLETE) {
            openReview();
            return true;
        }

        manager.resetToIdle();
        var menuView = new MainMenuView();
        WatchUi.switchToView(menuView, new MainMenuDelegate(menuView), WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onNextPage() as Boolean {
        var manager = AppContext.sessionManager();
        if (manager != null && manager.state() == Constants.SessionState.STATE_LISTENING) {
            manager.recordManualShot();
            return true;
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        var manager = AppContext.sessionManager();
        if (manager == null) {
            return true;
        }
        if (manager.state() == Constants.SessionState.STATE_COMPLETE) {
            openReview();
            return true;
        }
        return true;
    }

    function onMenu() as Boolean {
        var manager = AppContext.sessionManager();
        if (manager == null) {
            return true;
        }

        if (manager.state() == Constants.SessionState.STATE_LISTENING || manager.state() == Constants.SessionState.STATE_COUNTDOWN) {
            return true;
        }

        manager.resetToIdle();
        var menuView = new MainMenuView();
        WatchUi.switchToView(menuView, new MainMenuDelegate(menuView), WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var manager = AppContext.sessionManager();
        if (manager == null) {
            return false;
        }

        var key = evt.getKey();
        if ((WatchUi has :KEY_MENU) && key == WatchUi.KEY_MENU) {
            // Keep tap non-destructive; hold still routes through onMenu().
            return true;
        }

        var isStartKey = (WatchUi has :KEY_START) && key == WatchUi.KEY_START;
        var isEnterKey = (WatchUi has :KEY_ENTER) && key == WatchUi.KEY_ENTER;
        if (isStartKey || isEnterKey) {
            return onSelect();
        }

        if (manager.state() != Constants.SessionState.STATE_LISTENING) {
            return false;
        }

        if ((WatchUi has :KEY_LAP) && key == WatchUi.KEY_LAP) {
            manager.recordManualShot();
            return true;
        }
        if ((WatchUi has :KEY_ESC) && key == WatchUi.KEY_ESC) {
            manager.recordManualShot();
            return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            manager.recordManualShot();
            return true;
        }
        return false;
    }

    hidden function openReview() as Void {
        var manager = AppContext.sessionManager();
        if (manager == null || manager.activeSession() == null) {
            return;
        }

        var session = manager.activeSession() as SessionData;
        var review = new ReviewView(session);
        WatchUi.pushView(review, new ReviewDelegate(review), WatchUi.SLIDE_LEFT);
    }
}
