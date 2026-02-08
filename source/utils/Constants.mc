import Toybox.Graphics;

module Constants {
    enum SessionState {
        STATE_IDLE,
        STATE_READY,
        STATE_COUNTDOWN,
        STATE_LISTENING,
        STATE_COMPLETE
    }

    enum WeaponType {
        WEAPON_HANDGUN,
        WEAPON_RIFLE,
        WEAPON_SHOTGUN,
        WEAPON_PCC,
        WEAPON_CARBINE
    }

    enum DrillType {
        DRILL_FREESTYLE,
        DRILL_BILL_DRILL,
        DRILL_EL_PRES,
        DRILL_TRANSITION,
        DRILL_DOT_TORTURE
    }

    const APP_VERSION = "1.0.0";
    const CLOUD_UPLOAD_URL = "https://us-central1-topsnipes-15c41.cloudfunctions.net/garminSessionUpload";

    const STORAGE_SESSION_IDS = "topsnipes_session_ids";
    const STORAGE_PENDING_SYNC = "topsnipes_pending_syncs";
    const STORAGE_ACTIVE_SESSION = "topsnipes_active_session";

    const MAX_HISTORY = 120;
    const MAX_SPLITS_TO_DRAW = 5;

    const DEFAULT_COUNTDOWN_SECONDS = 10;
    const DEFAULT_DEBOUNCE_MS = 150;
    const DEFAULT_SENSITIVITY = 5;
    const DEFAULT_MAX_SHOTS = 0;

    const SHOT_POWER_MIN = 3000;
    const SHOT_POWER_MAX = 15000;
    const GPS_TIMEOUT_MS = 30000;

    const COLOR_BG = Graphics.COLOR_BLACK;
    const COLOR_TEXT = Graphics.COLOR_WHITE;
    const COLOR_ACCENT = Graphics.COLOR_GREEN;
    const COLOR_WARNING = Graphics.COLOR_YELLOW;
    const COLOR_ALERT = Graphics.COLOR_RED;
    const COLOR_SUBTLE = Graphics.COLOR_LT_GRAY;

    function weaponLabel(weapon as Number) as String {
        if (weapon == WeaponType.WEAPON_RIFLE) {
            return "Rifle";
        }
        if (weapon == WeaponType.WEAPON_SHOTGUN) {
            return "Shotgun";
        }
        if (weapon == WeaponType.WEAPON_PCC) {
            return "PCC";
        }
        if (weapon == WeaponType.WEAPON_CARBINE) {
            return "Carbine";
        }
        return "Handgun";
    }

    function drillLabel(drill as Number) as String {
        if (drill == DrillType.DRILL_BILL_DRILL) {
            return "Bill Drill";
        }
        if (drill == DrillType.DRILL_EL_PRES) {
            return "El Pres";
        }
        if (drill == DrillType.DRILL_TRANSITION) {
            return "Transition";
        }
        if (drill == DrillType.DRILL_DOT_TORTURE) {
            return "Dot Torture";
        }
        return "Freestyle";
    }
}
