// Override only the three device reads. Each test exercises the production
// watch face's wake and refresh paths without depending on a physical sensor.
class CountingPowerFace extends LcdFaceView {
    var live = 72;
    var liveReads = 0;
    var historyReads = 0;
    var latestReads = 0;

    function initialize() { LcdFaceView.initialize(); }

    function liveHeartRate() {
        liveReads += 1;
        return live;
    }

    function historyIterator() {
        historyReads += 1;
        return null;
    }

    function latestHeartRateSample() {
        latestReads += 1;
        return null;
    }
}

(:test)
function standbyReadsHistoryOnlyTwelveTimesPerHour(logger) {
    var face = new CountingPowerFace();
    for (var second = 0; second < 3600; second += 1) {
        face.refreshHeartRate(second);
    }
    return face.historyReads == 12 && face.liveReads == 60 && face.latestReads == 0;
}

(:test)
function repeatedWakeEventsNeverInvalidateHourlyHistoryCache(logger) {
    var face = new CountingPowerFace();
    face.live = null;
    for (var second = 0; second < 3600; second += 1) {
        face.onExitSleep();
        face.refreshHeartRate(second);
    }
    return face.historyReads == 12 && face.liveReads == 240 && face.latestReads == 228;
}

(:test)
function unchangedCurrentDoesNotInvalidateCachedFrame(logger) {
    var face = new CountingPowerFace();
    if (!face.refreshHeartRate(0)) { return false; }
    face.onExitSleep();
    if (face.refreshHeartRate(15)) { return false; }
    face.live = 75;
    face.onExitSleep();
    return face.refreshHeartRate(30) && face._model.current == 75;
}

(:test)
function minuteBoundaryStillRefreshesAfterRecentWake(logger) {
    var face = new CountingPowerFace();
    face.refreshHeartRate(44);
    face.onExitSleep();
    face.refreshHeartRate(59);
    face.refreshHeartRate(60);
    return face.historyReads == 1 && face.liveReads == 3;
}

(:test)
function clockMovingBackReloadsHistoryAndCurrent(logger) {
    var face = new CountingPowerFace();
    face.refreshHeartRate(10000);
    face.refreshHeartRate(9900);
    return face.historyReads == 2 && face.liveReads == 2;
}

(:test)
function newestReadingUpdatesCurrentWithoutRebuildingTrace(logger) {
    var model = new HeartRateModel();
    model.consume(new SampleIterator([new TestSample(9980, 68)]), 10000, null);
    var originalSamples = model.samples;
    model.updateCurrent(10200, null, null);
    if (model.current != null) { return false; }
    model.updateCurrent(10210, null, new TestSample(10205, 75));
    return model.current == 75 && model.samples == originalSamples && model.samples[59] == 68;
}

(:test)
function cachedCurrentRejectsFutureInvalidAndExpiredReadings(logger) {
    var model = new HeartRateModel();
    model.updateCurrent(10000, null, new TestSample(10001, 70));
    if (model.current != null) { return false; }
    model.updateCurrent(10000, null, new TestSample(9990, 256));
    if (model.current != null) { return false; }
    model.updateCurrent(10000, 80, new TestSample(9990, 70));
    if (model.current != 80) { return false; }
    model.updateCurrent(10100, null, null);
    if (model.current != 70) { return false; }
    model.updateCurrent(10170, null, null);
    if (model.current != 70) { return false; }
    model.updateCurrent(10171, null, null);
    return model.current == null;
}
