import Toybox.WatchUi;
import Toybox.Lang;

class MainMenuDelegate extends WatchUi.BehaviorDelegate {
    var _view as MainMenuView;

    function initialize(view as MainMenuView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.move(-1);
        return true;
    }

    function onSelect() as Boolean {
        var selected = _view.selectedIndex();
        if (selected == 0) {
            var configView = new SessionConfigView();
            WatchUi.pushView(configView, new SessionConfigDelegate(configView), WatchUi.SLIDE_LEFT);
            return true;
        }
        if (selected == 1) {
            var historyView = new HistoryView();
            WatchUi.pushView(historyView, new HistoryDelegate(historyView), WatchUi.SLIDE_LEFT);
            return true;
        }
        if (selected == 2) {
            var syncView = new SyncStatusView();
            WatchUi.pushView(syncView, new SyncStatusDelegate(syncView), WatchUi.SLIDE_LEFT);
            return true;
        }

        var settingsView = new SettingsInfoView();
        WatchUi.pushView(settingsView, new SettingsInfoDelegate(settingsView), WatchUi.SLIDE_LEFT);
        return true;
    }
}
