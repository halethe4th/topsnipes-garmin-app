(:test)
function testSplitCalculation() as Boolean {
    var session = new SessionData("test-1", Constants.WeaponType.WEAPON_HANDGUN, Constants.DrillType.DRILL_FREESTYLE, Constants.APP_VERSION, "sim");
    session.markStart(1000);
    session.recordShot(1200);
    session.recordShot(1500);
    session.recordShot(1830);

    if (session.shotCount != 3) {
        return false;
    }
    if (session.splitTimes.size() != 2) {
        return false;
    }
    return session.splitTimes[0] == 300 && session.splitTimes[1] == 330;
}

(:test)
function testStorageCloneGpsEncoding() as Boolean {
    var session = new SessionData("test-2", Constants.WeaponType.WEAPON_RIFLE, Constants.DrillType.DRILL_BILL_DRILL, Constants.APP_VERSION, "sim");
    session.markStart(2000);
    session.setGps(33.777123, -84.395321);
    session.recordShot(2500);
    var dict = session.cloneForStorage();

    return dict has "gpsLatE6" && dict has "gpsLonE6";
}

(:test)
function testTimerCountdownFloor() as Boolean {
    var timer = new TimerEngine();
    timer.setCountdownSeconds(0);
    timer.startCountdown();
    return timer.countdownSecondsRemaining() >= 1;
}

(:test)
function testSessionPreallocateLimit() as Boolean {
    var session = new SessionData("test-3", Constants.WeaponType.WEAPON_HANDGUN, Constants.DrillType.DRILL_FREESTYLE, Constants.APP_VERSION, "sim");
    session.markStart(1000);
    session.preallocate(2);
    session.recordShot(1300);
    session.recordShot(1600);
    session.recordShot(1900);
    return session.shotCount == 2;
}
