class RefreshSchedule {
    const HISTORY_SECONDS = 300;
    const WAKE_SECONDS = 15;
    var _historyAt = null;
    var _currentAt = null;
    var _wakeRequested = false;

    function initialize() {}

    function requestWake() { _wakeRequested = true; }

    function historyDue(now) {
        return _historyAt == null || now < _historyAt || now - _historyAt >= HISTORY_SECONDS;
    }

    function currentDue(now) {
        return _currentAt == null || now < _currentAt ||
            (now / 60).toNumber() != (_currentAt / 60).toNumber() ||
            (_wakeRequested && now - _currentAt >= WAKE_SECONDS);
    }

    function historyUpdated(now) { _historyAt = now; }

    function currentUpdated(now) {
        _currentAt = now;
        _wakeRequested = false;
    }
}
