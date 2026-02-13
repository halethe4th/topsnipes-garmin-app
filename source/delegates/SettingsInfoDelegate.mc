import Toybox.WatchUi;
import Toybox.Lang;


class SettingsInfoDelegate extends WatchUi.BehaviorDelegate {
    var _view as SettingsInfoView;

    function initialize(view as SettingsInfoView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onMenu() as Boolean {
        _view.move(1);
        return true;
    }

    function onNextPage() as Boolean {
        _view.adjustSelected(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.adjustSelected(-1);
        return true;
    }

    function onSelect() as Boolean {
        _view.move(1);
        return true;
    }
}
