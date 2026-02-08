using Toybox.Application;
using Toybox.WatchUi;

class TopSnipesApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new ShotTimerView();
        return [view, new ShotTimerDelegate(view)];
    }
}

class ShotTimerDelegate extends WatchUi.InputDelegate {
    var _view;

    function initialize(view) {
        InputDelegate.initialize();
        _view = view;
    }

    function onKey(keyEvent) {
        return _view.handleKey(keyEvent.getKey());
    }

    function onMenu() {
        return _view.openSettingsFromMenu();
    }
}
