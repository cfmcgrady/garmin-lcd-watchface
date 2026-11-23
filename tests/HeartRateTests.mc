import Toybox.Time;
import Toybox.Lang;

class SampleIterator {
    var entries as Array<TestSample>;
    var index = 0;
    function initialize(data) { entries = data; }
    function next() {
        if (index >= entries.size()) { return null; }
        var sample = entries[index];
        index += 1;
        return sample;
    }
}

class TestSample {
    var when;
    var data;
    function initialize(stamp, value) { when = new Time.Moment(stamp); data = value; }
}

(:test)
function missingReadingsStayMissing(logger) {
    var model = new HeartRateModel();
    model.consume(null, 10000, null);
    return model.current == null && model.samples[59] == null && model.high > model.low;
}

(:test)
function binsUseOneHourNotSixtySamples(logger) {
    var iterator = new SampleIterator([
        new TestSample(6400, 60), new TestSample(6460, 70),
        new TestSample(6490, 90), new TestSample(9880, 68),
        new TestSample(10000, 72), new TestSample(10001, 250)
    ]);
    var model = new HeartRateModel();
    model.consume(iterator, 10000, null);
    return model.samples[0] == 60 && model.samples[1] == 80 &&
        model.samples[58] == 68 && model.samples[59] == 72 &&
        model.samples[2] == null && model.current == 72;
}

(:test)
function staleHeartRateIsNotCurrent(logger) {
    var model = new HeartRateModel();
    model.consume(new SampleIterator([new TestSample(9700, 68)]), 10000, null);
    return model.current == null && model.samples[55] == 68;
}

(:test)
function invalidDataAndOutsideWindowAreIgnored(logger) {
    var model = new HeartRateModel();
    model.consume(new SampleIterator([
        new TestSample(6399, 60), new TestSample(9970, null),
        new TestSample(9980, 0), new TestSample(9990, 256)
    ]), 10000, 0);
    return model.current == null && model.samples[0] == null && model.samples[59] == null;
}

(:test)
function flatHistoryHasUsableScaleAndLiveReadingWins(logger) {
    var model = new HeartRateModel();
    model.consume(new SampleIterator([new TestSample(9980, 68)]), 10000, 75);
    return model.current == 75 && model.high - model.low >= 20;
}

(:test)
function twoMinuteSamplingConnectsButInvalidSamplesBreak(logger) {
    var model = new HeartRateModel();
    model.consume(new SampleIterator([
        new TestSample(9400, 60), new TestSample(9520, 65),
        new TestSample(9640, null), new TestSample(9760, 70),
        new TestSample(9880, 68)
    ]), 10000, null);
    return model.maxGap == 180 && model.samples[51] == null &&
        (model.timestamps[52] as Number) - (model.timestamps[50] as Number) <= model.maxGap &&
        model.breaks[54] == true && model.current == 68;
}
