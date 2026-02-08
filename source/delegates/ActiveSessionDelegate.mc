import Toybox.System;
import Toybox.WatchUi;

class ActiveSessionDelegate extends WatchUi.BehaviorDelegate {
    var _view as ActiveSessionView;
    var _menuKeyDownAt as Number;
    var _menuKeyArmed as Boolean;

    function initialize(view as ActiveSessionView) {
        BehaviorDelegate.initialize();
        _view = view;
        _menuKeyDownAt = 0;
        _menuKeyArmed = false;
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
        if (state == Constants.SessionState.STATE_COUNTDOWN) {
            manager.cancelCountdown();
            return true;
        }
        if (state == Constants.SessionState.STATE_LISTENING) {
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
            manager.cancelCountdown();
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
        return false;
    }

    function onPreviousPage() as Boolean {
        return false;
    }

    function onMenu() as Boolean {
        // Menu activation is handled with explicit key hold timing in onKeyPressed/onKeyReleased.
        return true;
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (isMenuHoldKey(key)) {
            _menuKeyDownAt = System.getTimer();
            _menuKeyArmed = true;
            return true;
        }
        return false;
    }

    function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {
        if (!_menuKeyArmed) {
            return false;
        }

        var key = evt.getKey();
        if (!isMenuHoldKey(key)) {
            return false;
        }

        _menuKeyArmed = false;
        var pressMs = System.getTimer() - _menuKeyDownAt;
        if (pressMs >= 650) {
            openSettings();
            return true;
        }

        var manager = AppContext.sessionManager();
        if (manager != null && manager.state() == Constants.SessionState.STATE_COMPLETE) {
            openReview();
            return true;
        }
        return true;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var manager = AppContext.sessionManager();
        if (manager == null) {
            return false;
        }

        var key = evt.getKey();

        var isStartKey = (WatchUi has :KEY_START) && key == WatchUi.KEY_START;
        var isEnterKey = (WatchUi has :KEY_ENTER) && key == WatchUi.KEY_ENTER;
        if (isStartKey || isEnterKey) {
            return onSelect();
        }

        if (manager.state() != Constants.SessionState.STATE_LISTENING) {
            return false;
        }

        if (isSplitKey(key)) {
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

    hidden function openSettings() as Void {
        var manager = AppContext.sessionManager();
        if (manager == null) {
            return;
        }
        var state = manager.state();
        if (state == Constants.SessionState.STATE_LISTENING || state == Constants.SessionState.STATE_COUNTDOWN) {
            return;
        }
        var settingsView = new SettingsInfoView();
        WatchUi.pushView(settingsView, new SettingsInfoDelegate(settingsView), WatchUi.SLIDE_UP);
    }

    hidden function isSplitKey(key as Number) as Boolean {
        if ((WatchUi has :KEY_LAP) && key == WatchUi.KEY_LAP) {
            return true;
        }
        if ((WatchUi has :KEY_ESC) && key == WatchUi.KEY_ESC) {
            return true;
        }
        return false;
    }

    hidden function isMenuHoldKey(key as Number) as Boolean {
        if ((WatchUi has :KEY_MENU) && key == WatchUi.KEY_MENU) {
            return true;
        }
        if ((WatchUi has :KEY_UP) && key == WatchUi.KEY_UP) {
            return true;
        }
        return false;
    }
}
