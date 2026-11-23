import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Application;

// Only compiled by preview.jungle; never included in the installable face.
class PreviewApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() { return [new PreviewFaceView()]; }
}

class PreviewFaceView extends LcdFaceView {
    function initialize() { LcdFaceView.initialize(); }
    function dateText(moment) { return "10月14日 周三"; }
    function timeText() { return "10:08"; }
    function batteryPercent() { return 82; }
    function refreshHeartRate(now) {
        _model.reset();
        _model.low = 48;
        _model.high = 80;
        _model.maxGap = 90;
        var readings = [59,60,59,62,61,64,62,61,60,61,59,60,58,59,58,57,58,57,56,57,
            56,57,57,56,58,59,58,57,58,56,57,58,57,58,59,59,61,60,59,60,
            62,61,62,64,63,62,63,65,64,65,67,66,67,69,68,67,68,69,68,68];
        for (var i=0; i<60; i+=1) {
            _model.samples[i] = readings[i];
            _model.timestamps[i] = now - 3540 + i*60;
        }
        _model.current = 68;
        return true;
    }
}
