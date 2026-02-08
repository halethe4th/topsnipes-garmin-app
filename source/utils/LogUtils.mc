import Toybox.System;

module LogUtils {
    (:debug)
    function debug(message as String) as Void {
        System.println(message);
    }
}
