import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class LcdFaceView extends WatchUi.WatchFace {
    const ACCENT = 0xAAFF00;
    const PRIMARY_TEXT = Graphics.COLOR_WHITE;
    const MUTED = 0xAAAAAA;
    const RULE = 0x555555;
    var _timeFont;
    var _dateFont;
    var _hrFont;
    var _smallFont;
    var _batteryFont;
    var _model as HeartRateModel;
    var _schedule as RefreshSchedule;
    var _frame = null;
    var _frameDirty = true;
    var _frameMinute = -1;
    var _weekdays as Array<String> = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"];

    function initialize() {
        WatchFace.initialize();
        _model = new HeartRateModel();
        _schedule = new RefreshSchedule();
    }

    function onLayout(dc) {
        _timeFont = WatchUi.loadResource(Rez.Fonts.TimeDigits);
        _dateFont = WatchUi.loadResource(Rez.Fonts.ChineseDate);
        _hrFont = WatchUi.loadResource(Rez.Fonts.HeartRateDigits);
        _smallFont = WatchUi.loadResource(Rez.Fonts.SmallText);
        _batteryFont = WatchUi.loadResource(Rez.Fonts.BatteryText);
        _frame = null;
        if ((Graphics has :BufferedBitmap) && System.getSystemStats().freeMemory >= 40000) {
            _frame = new Graphics.BufferedBitmap({
                :width => 240, :height => 240,
                :palette => [Graphics.COLOR_BLACK, PRIMARY_TEXT, ACCENT, MUTED, RULE]
            });
        }
        _frameDirty = true;
    }

    function onShow() { _frameDirty = true; }

    function onExitSleep() { _schedule.requestWake(); }

    function liveHeartRate() { return Activity.getActivityInfo().currentHeartRate; }

    function historyIterator() {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getHeartRateHistory)) {
            return SensorHistory.getHeartRateHistory({
                :period => new Time.Duration(3600),
                :order => SensorHistory.ORDER_OLDEST_FIRST
            });
        }
        return null;
    }

    function latestHeartRateSample() {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getHeartRateHistory)) {
            return SensorHistory.getHeartRateHistory({
                :period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST
            }).next();
        }
        return null;
    }

    function refreshHeartRate(now) {
        var historyDue = _schedule.historyDue(now);
        if (!historyDue && !_schedule.currentDue(now)) { return false; }
        var previousCurrent = _model.current;
        var live = liveHeartRate();
        if (historyDue) {
            _model.consume(historyIterator(), now, live);
            _schedule.historyUpdated(now);
        } else {
            var latest = _model.valid(live) ? null : latestHeartRateSample();
            _model.updateCurrent(now, live, latest);
        }
        _schedule.currentUpdated(now);
        return historyDue || previousCurrent != _model.current;
    }

    function dateText(moment) {
        var date = Gregorian.info(moment, Time.FORMAT_SHORT);
        return date.month.toString() + "月" + date.day.toString() + "日 " + _weekdays[date.day_of_week];
    }

    function timeText() {
        var clock = System.getClockTime();
        return clock.hour.format("%02d") + ":" + clock.min.format("%02d");
    }

    function batteryPercent() { return System.getSystemStats().battery.toNumber(); }

    function onUpdate(dc) {
        var moment = Time.now();
        var changed = refreshHeartRate(moment.value());
        var minute = (moment.value() / 60).toNumber();
        if (_frame == null) {
            drawFace(dc, moment);
            return;
        }
        if (_frameDirty || changed || minute != _frameMinute) {
            drawFace(_frame.getDc(), moment);
            _frameDirty = false;
            _frameMinute = minute;
        }
        dc.drawBitmap(0, 0, _frame);
    }

    function drawFace(dc, moment) {
        dc.setColor(PRIMARY_TEXT, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(120, 36, _dateFont, dateText(moment), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(120, 73, _timeFont, timeText(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(RULE, Graphics.COLOR_BLACK);
        dc.drawLine(28, 155, 212, 155);
        dc.drawLine(120, 164, 120, 201);
        dc.setColor(MUTED, Graphics.COLOR_BLACK);
        dc.drawText(35, 163, _smallFont, "HR · 1H", Graphics.TEXT_JUSTIFY_LEFT);
        drawHistory(dc);
        drawHeart(dc, 130, 173);
        drawCurrentHeartRate(dc);
        drawBattery(dc, batteryPercent());
    }

    function drawHistory(dc) {
        var lastX = null;
        var lastY = null;
        var lastStamp = 0;
        var hasData = false;
        dc.setColor(RULE, Graphics.COLOR_BLACK);
        dc.drawLine(35, 199, 110, 199);
        dc.setColor(ACCENT, Graphics.COLOR_BLACK);
        for (var i = 0; i < 60; i += 1) {
            var value = _model.samples[i];
            if (_model.breaks[i] == true) {
                lastX = null;
                lastY = null;
                lastStamp = 0;
            }
            if (value == null) {
                continue;
            }
            hasData = true;
            var x = 35 + (75.0 * i / 59).toNumber();
            var y = 195 - (19.0 * (value - _model.low) / (_model.high - _model.low)).toNumber();
            var stamp = _model.timestamps[i];
            if (lastX != null && stamp != null && stamp - lastStamp <= _model.maxGap) {
                dc.drawLine(lastX, lastY, x, y);
            }
            else { dc.fillRectangle(x, y, 1, 1); }
            lastX = x;
            lastY = y;
            lastStamp = stamp as Number;
        }
        if (!hasData) {
            dc.setColor(MUTED, Graphics.COLOR_BLACK);
            dc.drawText(73, 182, _smallFont, "--", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawHeart(dc, x, y) {
        dc.setColor(ACCENT, Graphics.COLOR_BLACK);
        dc.fillCircle(x + 5, y + 5, 5);
        dc.fillCircle(x + 13, y + 5, 5);
        dc.fillPolygon([[x, y + 6], [x + 18, y + 6], [x + 9, y + 19]]);
    }

    function drawCurrentHeartRate(dc) {
        var text = _model.current == null ? "--" : _model.current.toString();
        var width = dc.getTextWidthInPixels(text, _hrFont);
        var unitWidth = dc.getTextWidthInPixels("BPM", _smallFont);
        var x = 157;
        if (x + width + 3 + unitWidth > 213) { x = 213 - width - 3 - unitWidth; }
        dc.setColor(PRIMARY_TEXT, Graphics.COLOR_BLACK);
        dc.drawText(x, 173, _hrFont, text, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(MUTED, Graphics.COLOR_BLACK);
        dc.drawText(x + width + 3, 184, _smallFont, "BPM", Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawBattery(dc, percent) {
        if (percent < 0) { percent = 0; }
        if (percent > 100) { percent = 100; }
        var text = percent.toString() + "%";
        var textWidth = dc.getTextWidthInPixels(text, _batteryFont);
        var x = ((240 - (23 + 6 + textWidth)) / 2).toNumber();
        dc.setColor(PRIMARY_TEXT, Graphics.COLOR_BLACK);
        dc.drawRectangle(x, 211, 21, 11);
        dc.fillRectangle(x + 21, 214, 2, 5);
        dc.setColor(ACCENT, Graphics.COLOR_BLACK);
        var fill = (17.0 * percent / 100).toNumber();
        if (fill > 0) { dc.fillRectangle(x + 2, 213, fill, 7); }
        dc.setColor(PRIMARY_TEXT, Graphics.COLOR_BLACK);
        dc.drawText(x + 29, 210, _batteryFont, text, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
