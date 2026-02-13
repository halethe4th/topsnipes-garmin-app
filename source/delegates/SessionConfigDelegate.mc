import Toybox.WatchUi;
import Toybox.Lang;


class SessionConfigDelegate extends WatchUi.BehaviorDelegate {
    var _view as SessionConfigView;

    function initialize(view as SessionConfigView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onNextPage() as Boolean {
        if (_view.selectedRow() == 3) {
            _view.moveRow(1);
            return true;
        }
        _view.adjustSelected(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        if (_view.selectedRow() == 3) {
            _view.moveRow(-1);
            return true;
        }
        _view.adjustSelected(-1);
        return true;
    }

    function onMenu() as Boolean {
        _view.moveRow(1);
        return true;
    }

    function onSelect() as Boolean {
        if (_view.selectedRow() != 3) {
            _view.moveRow(1);
            return true;
        }

        var manager = AppContext.sessionManager();
        if (manager != null) {
            manager.beginNewSession(_view.weaponType(), _view.drillType(), _view.maxShots());
        }

        var activeView = new ActiveSessionView();
        WatchUi.switchToView(activeView, new ActiveSessionDelegate(activeView), WatchUi.SLIDE_LEFT);
        return true;
    }
}
