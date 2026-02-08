import Toybox.WatchUi;

class HistoryDelegate extends WatchUi.BehaviorDelegate {
    var _view as HistoryView;

    function initialize(view as HistoryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
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
        var session = _view.selectedSession();
        if (session == null) {
            return true;
        }

        var review = new ReviewView(session);
        WatchUi.pushView(review, new ReviewDelegate(review), WatchUi.SLIDE_LEFT);
        return true;
    }
}
