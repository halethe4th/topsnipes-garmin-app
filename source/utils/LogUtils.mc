import Toybox.System;
import Toybox.Lang;


module LogUtils {
    (:debug)
    function debug(message as String) as Void {
        System.println(message);
    }
}
