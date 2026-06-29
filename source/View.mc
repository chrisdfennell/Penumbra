import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;

// Penumbra - a bright, data-dense digital watch face. Three big digit groups
// show HH MM SS (accent-coloured seconds), surrounded by a full ring of icon
// complications. Light and dark themes plus a selectable accent colour. Everything
// is laid out relative to the screen size so the same source scales across every
// round panel.
class PenumbraView extends WatchUi.WatchFace {

    // ---- Settings (mirrored from Properties; see loadSettings) -----------------
    private var mTheme as Number = 0;        // 0 = Light, 1 = Dark
    private var mAccentIdx as Number = 0;    // index into ACCENTS
    private var mShowSeconds as Boolean = true;
    private var mShowDate as Boolean = true;
    private var mShowWeather as Boolean = true;

    // ---- Resolved theme colours (set in onUpdate from mTheme) ------------------
    private var mBg as Number = Graphics.COLOR_WHITE;
    private var mInk as Number = Graphics.COLOR_BLACK;   // digits / primary text
    private var mText as Number = 0x222222;              // complication values
    private var mMuted as Number = 0x888888;             // complication labels
    private var mIcon as Number = 0x505050;              // complication icons
    private var mAccent as Number = 0xF08A1E;            // card colour

    // Accent palette, indexed by the Accent property.
    private const ACCENTS = [0xF08A1E, 0x2E7DE0, 0x2EA84F, 0xE23B2E, 0xF2C400];

    // Complication icon bitmaps, keyed by name. Black set for the Light theme,
    // white set for the Dark theme (Garmin can't recolour a bitmap at runtime).
    private var mIconBlack as Dictionary = {};
    private var mIconWhite as Dictionary = {};

    function initialize() {
        WatchFace.initialize();
        loadSettings();
        loadIcons();
    }

    // Load both colour variants of every complication icon once at startup.
    function loadIcons() as Void {
        mIconBlack = {
            "alarm"     => WatchUi.loadResource(Rez.Drawables.IconAlarmBlack),
            "battery"   => WatchUi.loadResource(Rez.Drawables.IconBatteryBlack),
            "bell"      => WatchUi.loadResource(Rez.Drawables.IconBellBlack),
            "bolt"      => WatchUi.loadResource(Rez.Drawables.IconBoltBlack),
            "flame"     => WatchUi.loadResource(Rez.Drawables.IconFlameBlack),
            "footprint" => WatchUi.loadResource(Rez.Drawables.IconFootprintBlack),
            "heart"     => WatchUi.loadResource(Rez.Drawables.IconHeartBlack),
            "route"     => WatchUi.loadResource(Rez.Drawables.IconRouteBlack),
            "stairs"    => WatchUi.loadResource(Rez.Drawables.IconStairsBlack),
            "sun"       => WatchUi.loadResource(Rez.Drawables.IconSunBlack),
            "sunny"        => WatchUi.loadResource(Rez.Drawables.IconSunnyBlack),
            "partly-cloudy" => WatchUi.loadResource(Rez.Drawables.IconPartlyCloudyBlack),
            "cloudy"       => WatchUi.loadResource(Rez.Drawables.IconCloudyBlack),
            "rain"         => WatchUi.loadResource(Rez.Drawables.IconRainBlack),
            "snow"         => WatchUi.loadResource(Rez.Drawables.IconSnowBlack),
            "thunderstorm" => WatchUi.loadResource(Rez.Drawables.IconThunderstormBlack),
            "windy"        => WatchUi.loadResource(Rez.Drawables.IconWindyBlack),
            "fog"          => WatchUi.loadResource(Rez.Drawables.IconFogBlack),
            "wintry-mix"   => WatchUi.loadResource(Rez.Drawables.IconWintryMixBlack)
        };
        mIconWhite = {
            "alarm"     => WatchUi.loadResource(Rez.Drawables.IconAlarmWhite),
            "battery"   => WatchUi.loadResource(Rez.Drawables.IconBatteryWhite),
            "bell"      => WatchUi.loadResource(Rez.Drawables.IconBellWhite),
            "bolt"      => WatchUi.loadResource(Rez.Drawables.IconBoltWhite),
            "flame"     => WatchUi.loadResource(Rez.Drawables.IconFlameWhite),
            "footprint" => WatchUi.loadResource(Rez.Drawables.IconFootprintWhite),
            "heart"     => WatchUi.loadResource(Rez.Drawables.IconHeartWhite),
            "route"     => WatchUi.loadResource(Rez.Drawables.IconRouteWhite),
            "stairs"    => WatchUi.loadResource(Rez.Drawables.IconStairsWhite),
            "sun"       => WatchUi.loadResource(Rez.Drawables.IconSunWhite),
            "sunny"        => WatchUi.loadResource(Rez.Drawables.IconSunnyWhite),
            "partly-cloudy" => WatchUi.loadResource(Rez.Drawables.IconPartlyCloudyWhite),
            "cloudy"       => WatchUi.loadResource(Rez.Drawables.IconCloudyWhite),
            "rain"         => WatchUi.loadResource(Rez.Drawables.IconRainWhite),
            "snow"         => WatchUi.loadResource(Rez.Drawables.IconSnowWhite),
            "thunderstorm" => WatchUi.loadResource(Rez.Drawables.IconThunderstormWhite),
            "windy"        => WatchUi.loadResource(Rez.Drawables.IconWindyWhite),
            "fog"          => WatchUi.loadResource(Rez.Drawables.IconFogWhite),
            "wintry-mix"   => WatchUi.loadResource(Rez.Drawables.IconWintryMixWhite)
        };
    }

    // The bitmap for an icon in the current theme.
    private function icon(name as String) as WatchUi.BitmapResource? {
        var d = (mTheme == 1) ? mIconWhite : mIconBlack;
        return d[name] as WatchUi.BitmapResource?;
    }

    // Draw an icon centred on (cx, cy) at its native size.
    private function drawIcon(dc as Dc, name as String, cx as Number, cy as Number) as Void {
        var bmp = icon(name);
        if (bmp == null) { return; }
        dc.drawBitmap(cx - bmp.getWidth() / 2, cy - bmp.getHeight() / 2, bmp);
    }

    function onLayout(dc as Dc) as Void {
    }

    // Pull the user's settings out of the property store. Called at init and again
    // from the App's onSettingsChanged().
    function loadSettings() as Void {
        mTheme       = propNumber("Theme", 0);
        mAccentIdx   = propNumber("Accent", 0);
        mShowSeconds = propBool("ShowSeconds", true);
        mShowDate    = propBool("ShowDate", true);
        mShowWeather = propBool("ShowWeather", true);
        if (mAccentIdx < 0 || mAccentIdx >= ACCENTS.size()) { mAccentIdx = 0; }
    }

    private function propNumber(key as String, dflt as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v == null) { return dflt; }
        return v.toNumber();
    }

    private function propBool(key as String, dflt as Boolean) as Boolean {
        var v = Application.Properties.getValue(key);
        if (v == null) { return dflt; }
        return v;
    }

    // ---- Main render -----------------------------------------------------------
    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        resolveTheme();

        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        // Clear to background.
        dc.setColor(mBg, mBg);
        dc.clear();

        drawTopCluster(dc, w, h, cx);
        drawTimeCards(dc, w, h, cx);
        drawComplications(dc, w, h, cx);
    }

    private function resolveTheme() as Void {
        mAccent = ACCENTS[mAccentIdx];
        if (mTheme == 1) {
            mBg    = Graphics.COLOR_BLACK;
            mInk   = Graphics.COLOR_WHITE;
            mText  = 0xEFEFEF;
            mMuted = 0x9A9A9A;
            mIcon  = 0xC8C8C8;
        } else {
            mBg    = Graphics.COLOR_WHITE;
            mInk   = Graphics.COLOR_BLACK;
            mText  = 0x202020;
            mMuted = 0x808080;
            mIcon  = 0x484848;
        }
    }

    // ===========================================================================
    //  Time cards
    // ===========================================================================
    private function drawTimeCards(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        var clock = System.getClockTime();
        var is24 = System.getDeviceSettings().is24Hour;

        var hour = clock.hour;
        if (!is24) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var hh = pad2(hour);
        var mm = pad2(clock.min);
        var ss = pad2(clock.sec);

        var showSec = mShowSeconds;

        // Card geometry, proportional to the screen.
        var cardH  = (h * 0.175).toNumber();
        var mainW  = (w * 0.225).toNumber();
        var ssW    = (w * 0.135).toNumber();
        var gap    = (w * 0.020).toNumber();
        var radius = (cardH * 0.16).toNumber();

        var totalW = showSec ? (mainW * 2 + ssW + gap * 2) : (mainW * 2 + gap);
        var startX = cx - totalW / 2;
        var cardTop = (h * 0.50).toNumber() - cardH / 2;

        var hhX = startX;
        var mmX = startX + mainW + gap;
        var ssX = mmX + mainW + gap;

        var ssH = (cardH * 0.62).toNumber();
        var ssTop = cardTop + (cardH - ssH) / 2;

        // Pick the largest numeric font that fits the main card, then drop the
        // seconds to a smaller tier so they read clearly smaller than HH/MM.
        var mainIdx  = pickNumberFontIndex(dc, "00", (mainW * 0.84).toNumber(), (cardH * 0.84).toNumber());
        var mainFont = NUMBER_FONTS[mainIdx];
        var ssIdx    = mainIdx + 1;
        if (ssIdx >= NUMBER_FONTS.size()) { ssIdx = NUMBER_FONTS.size() - 1; }
        var ssFont   = NUMBER_FONTS[ssIdx];

        // Main HH / MM cards.
        drawCard(dc, hhX, cardTop, mainW, cardH, radius, hh, mainFont, mInk);
        drawCard(dc, mmX, cardTop, mainW, cardH, radius, mm, mainFont, mInk);

        // Smaller seconds card, vertically centred on the same row.
        if (showSec) {
            drawCard(dc, ssX, ssTop, ssW, ssH, (radius * 0.8).toNumber(), ss, ssFont, mAccent);
        }
    }

    private function drawCard(dc as Dc, x as Number, y as Number, cw as Number, ch as Number,
                              r as Number, text as String, font as FontType, color as Number) as Void {
        // Draw digits directly with mInk / mAccent color (no background card box)
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + cw / 2, y + ch / 2, font, text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ===========================================================================
    //  Top cluster: date pill, time mode, device battery
    // ===========================================================================
    private function drawTopCluster(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        // Device battery, very top centre.
        var batt = System.getSystemStats().battery;
        if (batt != null) {
            var battY = (h * 0.105).toNumber();
            var battStr = batt.format("%d") + "%";
            var bsw = dc.getTextWidthInPixels(battStr, Graphics.FONT_XTINY);
            var battBmp = icon("battery");
            var battW = (battBmp != null) ? battBmp.getWidth() : 0;
            // Icon to the left of the percentage, the pair centred on cx.
            drawIcon(dc, "battery", (cx - bsw / 2 - battW / 2).toNumber(), battY);
            dc.setColor(mMuted, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + (battW / 2).toNumber(), battY, Graphics.FONT_XTINY, battStr,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (mShowDate) {
            var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            var dateStr = now.day_of_week + " " + now.day.format("%02d");

            var font = Graphics.FONT_SMALL;
            var tw = dc.getTextWidthInPixels(dateStr, font);
            var padX = (w * 0.04).toNumber();
            var pillW = tw + padX * 2;
            var pillH = (dc.getFontHeight(font) * 1.05).toNumber();
            var pillY = (h * 0.185).toNumber();
            var pillX = cx - pillW / 2;

            // In 12-hour mode, suffix AM/PM so the date pill carries the meridian
            // instead of a separate line that crowded the pill.
            if (!System.getDeviceSettings().is24Hour) {
                var ap = (System.getClockTime().hour < 12) ? " AM" : " PM";
                dateStr = dateStr + ap;
                tw = dc.getTextWidthInPixels(dateStr, font);
                pillW = tw + padX * 2;
                pillX = cx - pillW / 2;
            }

            // Draw date text directly onto the background in mInk color
            dc.setColor(mInk, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, pillY, font, dateStr,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Weather line below the date, if available and enabled. The icon reflects
        // the actual current sky condition.
        if (mShowWeather && (Toybox has :Weather)) {
            var cond = Weather.getCurrentConditions();
            if (cond != null) {
                var wx = weatherTempString(cond);
                if (wx != null) {
                    var iconName = (cond.condition != null) ? weatherIconName(cond.condition) : "sun";
                    var wy = (h * 0.265).toNumber();
                    var www = dc.getTextWidthInPixels(wx, Graphics.FONT_XTINY);
                    var wBmp = icon(iconName);
                    var wIconW = (wBmp != null) ? wBmp.getWidth() : 0;
                    drawIcon(dc, iconName, (cx - www / 2 - wIconW / 2).toNumber(), wy);
                    dc.setColor(mText, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(cx + (wIconW / 2).toNumber(), wy, Graphics.FONT_XTINY, wx,
                                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }
        }
    }

    // ===========================================================================
    //  Complication ring
    // ===========================================================================
    private function drawComplications(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        var mon = ActivityMonitor.getInfo();
        var settings = System.getDeviceSettings();

        // Upper flanks: alarms (left), notifications (right).
        drawCell(dc, (w * 0.225).toNumber(), (h * 0.235).toNumber(),
                 "alarm", numOrDash(settings.alarmCount));
        drawCell(dc, (w * 0.775).toNumber(), (h * 0.235).toNumber(),
                 "bell", numOrDash(settings.notificationCount));

        // Heart rate tucks into the margin left of the hours card; body battery into
        // the margin right of the seconds card. The card row is the widest part of
        // the round screen, so these fit beside the digits without clipping.
        drawCell(dc, (w * 0.085).toNumber(), (h * 0.50).toNumber(),
                 "heart", numOrDash(getHeartRate()));
        drawCell(dc, (w * 0.915).toNumber(), (h * 0.50).toNumber(),
                 "bolt", percentOrDash(getBodyBattery()));

        // Lower row under the cards: distance, calories, floors - all on one line.
        drawCell(dc, (w * 0.275).toNumber(), (h * 0.685).toNumber(),
                 "route", distanceString(mon, settings));
        drawCell(dc, (w * 0.50).toNumber(), (h * 0.685).toNumber(),
                 "flame", numOrDash(mon != null ? mon.calories : null));
        drawCell(dc, (w * 0.725).toNumber(), (h * 0.685).toNumber(),
                 "stairs", floorsString(mon));

        // Steps, bottom centre: foot icon above, number below. Kept clear of the
        // bottom bezel.
        var steps = (mon != null) ? mon.steps : null;
        var stepsStr = (steps != null) ? steps.format("%d") : "--";
        drawIcon(dc, "footprint", cx, (h * 0.795).toNumber());
        dc.setColor(mInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.865).toNumber(), Graphics.FONT_MEDIUM, stepsStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A complication cell: icon on top, value below, centred on (x, y).
    private function drawCell(dc as Dc, x as Number, y as Number, name as String, value as String) as Void {
        var labelH = dc.getFontHeight(Graphics.FONT_XTINY);
        drawIcon(dc, name, x, (y - labelH * 0.45).toNumber());
        dc.setColor(mText, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + labelH * 0.55, Graphics.FONT_XTINY, value,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ===========================================================================
    //  Data getters (all guarded so a missing sensor never crashes the face)
    // ===========================================================================
    private function getHeartRate() as Number or Null {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getHeartRateHistory)) {
            var it = Toybox.SensorHistory.getHeartRateHistory({:period => 1, :order => Toybox.SensorHistory.ORDER_NEWEST_FIRST});
            if (it != null) {
                var s = it.next();
                if (s != null && s.data != null) { return s.data.toNumber(); }
            }
        }
        return null;
    }

    private function getBodyBattery() as Number or Null {
        if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
            var it = Toybox.SensorHistory.getBodyBatteryHistory({:period => 1, :order => Toybox.SensorHistory.ORDER_NEWEST_FIRST});
            if (it != null) {
                var s = it.next();
                if (s != null && s.data != null) { return s.data.toNumber(); }
            }
        }
        return null;
    }

    private function distanceString(mon as ActivityMonitor.Info or Null, settings as System.DeviceSettings) as String {
        if (mon == null || mon.distance == null) { return "--"; }
        var cm = mon.distance.toFloat();
        var dist = (settings.distanceUnits == System.UNIT_METRIC) ? (cm / 100000.0) : (cm / 160934.4);
        return dist.format("%.2f");
    }

    private function floorsString(mon as ActivityMonitor.Info or Null) as String {
        if (mon == null || !(mon has :floorsClimbed) || mon.floorsClimbed == null) { return "--"; }
        return mon.floorsClimbed.format("%d");
    }

    // Temperature line ("72°  75/60") from an already-fetched conditions object.
    private function weatherTempString(cond as Weather.CurrentConditions) as String or Null {
        if (cond.temperature == null) { return null; }
        var metric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
        var t = cond.temperature.toFloat();        // Celsius
        var hi = cond.highTemperature;
        var lo = cond.lowTemperature;
        if (!metric) {
            t = t * 9.0 / 5.0 + 32.0;
            if (hi != null) { hi = (hi.toFloat() * 9.0 / 5.0 + 32.0).toNumber(); }
            if (lo != null) { lo = (lo.toFloat() * 9.0 / 5.0 + 32.0).toNumber(); }
        }
        var s = t.format("%d") + "°";
        if (hi != null && lo != null) {
            s = s + "  " + hi.format("%d") + "/" + lo.format("%d");
        }
        return s;
    }

    // Map a Weather condition enum to one of our condition icon names.
    private function weatherIconName(cond as Number) as String {
        if (cond == Weather.CONDITION_CLEAR || cond == Weather.CONDITION_FAIR ||
            cond == Weather.CONDITION_MOSTLY_CLEAR || cond == Weather.CONDITION_PARTLY_CLEAR) {
            return "sunny";
        }
        if (cond == Weather.CONDITION_PARTLY_CLOUDY || cond == Weather.CONDITION_THIN_CLOUDS) {
            return "partly-cloudy";
        }
        if (cond == Weather.CONDITION_MOSTLY_CLOUDY || cond == Weather.CONDITION_CLOUDY) {
            return "cloudy";
        }
        if (cond == Weather.CONDITION_RAIN || cond == Weather.CONDITION_LIGHT_RAIN ||
            cond == Weather.CONDITION_HEAVY_RAIN || cond == Weather.CONDITION_SHOWERS ||
            cond == Weather.CONDITION_LIGHT_SHOWERS || cond == Weather.CONDITION_HEAVY_SHOWERS ||
            cond == Weather.CONDITION_SCATTERED_SHOWERS || cond == Weather.CONDITION_CHANCE_OF_SHOWERS ||
            cond == Weather.CONDITION_DRIZZLE || cond == Weather.CONDITION_UNKNOWN_PRECIPITATION ||
            cond == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN) {
            return "rain";
        }
        if (cond == Weather.CONDITION_SNOW || cond == Weather.CONDITION_LIGHT_SNOW ||
            cond == Weather.CONDITION_HEAVY_SNOW || cond == Weather.CONDITION_FLURRIES ||
            cond == Weather.CONDITION_CHANCE_OF_SNOW || cond == Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW) {
            return "snow";
        }
        if (cond == Weather.CONDITION_THUNDERSTORMS || cond == Weather.CONDITION_SCATTERED_THUNDERSTORMS ||
            cond == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS) {
            return "thunderstorm";
        }
        if (cond == Weather.CONDITION_WINDY || cond == Weather.CONDITION_SQUALL ||
            cond == Weather.CONDITION_HURRICANE || cond == Weather.CONDITION_TROPICAL_STORM ||
            cond == Weather.CONDITION_TORNADO || cond == Weather.CONDITION_SANDSTORM) {
            return "windy";
        }
        if (cond == Weather.CONDITION_FOG || cond == Weather.CONDITION_MIST ||
            cond == Weather.CONDITION_HAZY || cond == Weather.CONDITION_HAZE ||
            cond == Weather.CONDITION_SMOKE || cond == Weather.CONDITION_DUST ||
            cond == Weather.CONDITION_SAND || cond == Weather.CONDITION_VOLCANIC_ASH) {
            return "fog";
        }
        if (cond == Weather.CONDITION_WINTRY_MIX || cond == Weather.CONDITION_RAIN_SNOW ||
            cond == Weather.CONDITION_LIGHT_RAIN_SNOW || cond == Weather.CONDITION_HEAVY_RAIN_SNOW ||
            cond == Weather.CONDITION_FREEZING_RAIN || cond == Weather.CONDITION_SLEET ||
            cond == Weather.CONDITION_HAIL || cond == Weather.CONDITION_ICE ||
            cond == Weather.CONDITION_ICE_SNOW || cond == Weather.CONDITION_CHANCE_OF_RAIN_SNOW ||
            cond == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW) {
            return "wintry-mix";
        }
        return "partly-cloudy";
    }

    // ===========================================================================
    //  Small helpers
    // ===========================================================================
    // Numeric system fonts, largest to smallest.
    private const NUMBER_FONTS = [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT,
                                  Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD];

    private function pickNumberFontIndex(dc as Dc, sample as String, maxW as Number, maxH as Number) as Number {
        for (var i = 0; i < NUMBER_FONTS.size(); i++) {
            if (dc.getFontHeight(NUMBER_FONTS[i]) <= maxH &&
                dc.getTextWidthInPixels(sample, NUMBER_FONTS[i]) <= maxW) {
                return i;
            }
        }
        return NUMBER_FONTS.size() - 1;
    }

    private function pad2(n as Number) as String {
        return n.format("%02d");
    }

    private function numOrDash(n as Number or Null) as String {
        return (n != null) ? n.format("%d") : "--";
    }

    private function percentOrDash(n as Number or Null) as String {
        return (n != null) ? n.format("%d") + "%" : "--";
    }
}
