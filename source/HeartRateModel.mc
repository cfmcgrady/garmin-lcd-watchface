import Toybox.Lang;

// Fixed wall-clock bins: sample count never substitutes for elapsed time.
// Explicit invalid readings and long gaps break the trace; normal device
// sampling intervals may span more than one minute and must still connect.
class HeartRateModel {
    var samples as Array<Number?> = new Array<Number?>[60];
    var timestamps as Array<Number?> = new Array<Number?>[60];
    var breaks as Array<Boolean?> = new Array<Boolean?>[60];
    var maxGap = 90.0;
    var current;
    var low;
    var high;
    var _latestTime = 0;
    var _latestValue = null;

    function initialize() { reset(); }

    function reset() {
        samples = new Array<Number?>[60];
        timestamps = new Array<Number?>[60];
        breaks = new Array<Boolean?>[60];
        maxGap = 90.0;
        current = null;
        low = 50;
        high = 90;
        _latestTime = 0;
        _latestValue = null;
    }

    function valid(value) {
        return value != null && value > 0 && value <= 255;
    }

    function consume(iterator, now, liveHeartRate) {
        reset();
        var sums = new [60];
        var counts = new [60];
        var start = now - 3600;
        var readCount = 0;
        var previousStamp = null;
        var cadence = null;
        if (iterator != null) {
            var sample = iterator.next();
            while (sample != null && readCount < 4096) {
                readCount += 1;
                var stamp = sample.when.value();
                if (stamp >= start && stamp <= now) {
                    var bin = ((stamp - start) / 60).toNumber();
                    if (bin > 59) { bin = 59; }
                    if (previousStamp != null && stamp > previousStamp) {
                        var interval = stamp - previousStamp;
                        if (cadence == null || interval < cadence) { cadence = interval; }
                    }
                    previousStamp = stamp;
                    if (!valid(sample.data)) {
                        breaks[bin] = true;
                    } else {
                        if (counts[bin] == null) {
                            counts[bin] = 0;
                            sums[bin] = 0.0;
                        }
                        sums[bin] += sample.data;
                        counts[bin] += 1;
                        timestamps[bin] = stamp;
                        if (stamp >= _latestTime) {
                            _latestTime = stamp;
                            _latestValue = sample.data.toNumber();
                        }
                    }
                }
                sample = iterator.next();
            }
        }
        if (cadence != null && cadence * 1.5 > maxGap) { maxGap = cadence * 1.5; }
        if (maxGap > 300) { maxGap = 300; }
        var minValue = null;
        var maxValue = null;
        for (var i = 0; i < 60; i += 1) {
            if (counts[i] != null) {
                samples[i] = (sums[i] / counts[i]).toNumber();
                if (minValue == null || samples[i] < minValue) { minValue = samples[i]; }
                if (maxValue == null || samples[i] > maxValue) { maxValue = samples[i]; }
            }
        }
        if (minValue != null) {
            low = minValue - 5;
            high = maxValue + 5;
            if (high - low < 20) {
                var mid = ((minValue + maxValue) / 2).toNumber();
                low = mid - 10;
                high = mid + 10;
            }
            if (low < 0) { low = 0; }
        }
        updateCurrent(now, liveHeartRate, null);
    }

    function updateCurrent(now, liveHeartRate, latestSample) {
        if (latestSample != null && valid(latestSample.data)) {
            var stamp = latestSample.when.value();
            if (stamp <= now && stamp >= _latestTime) {
                _latestTime = stamp;
                _latestValue = latestSample.data.toNumber();
            }
        }
        if (valid(liveHeartRate)) {
            current = liveHeartRate.toNumber();
        } else if (_latestValue != null && now >= _latestTime && now - _latestTime <= 180) {
            current = _latestValue;
        } else {
            current = null;
        }
    }
}
