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
    private var mShowArc as Boolean = true;  // step-goal eclipse ring
    private var mShowHrGraph as Boolean = false;  // HR trend sparkline (lower band)

    // Configurable complication slots. Each holds a data-type id (DATA_* below).
    private var mSlotML as Number = 0;  // margin left  - default Heart Rate
    private var mSlotMR as Number = 1;  // margin right - default Body Battery
    private var mSlotLL as Number = 4;  // lower left   - default Distance
    private var mSlotLC as Number = 3;  // lower centre - default Calories
    private var mSlotLR as Number = 5;  // lower right  - default Floors

    // Data types a slot can show. Mirrored in settings.xml list entries.
    private const DATA_HR       = 0;
    private const DATA_BB       = 1;
    private const DATA_STEPS    = 2;
    private const DATA_CALORIES = 3;
    private const DATA_DISTANCE = 4;
    private const DATA_FLOORS   = 5;
    private const DATA_ALARMS   = 6;
    private const DATA_NOTIFS   = 7;
    private const DATA_NONE     = 8;

    // ---- Resolved theme colours (set in onUpdate from mTheme) ------------------
    private var mBg as Number = Graphics.COLOR_WHITE;
    private var mInk as Number = Graphics.COLOR_BLACK;   // digits / primary text
    private var mText as Number = 0x222222;              // complication values
    private var mMuted as Number = 0x888888;             // complication labels
    private var mIcon as Number = 0x505050;              // complication icons
    private var mAccent as Number = 0xF08A1E;            // card colour

    // ---- Power state + seconds geometry ---------------------------------------
    // mLowPower tracks sleep/always-on; the seconds fields are cached each full
    // render so onPartialUpdate can retick just the seconds glyph in place.
    private var mLowPower as Boolean = false;
    private var mSecCx as Number = 0;
    private var mSecCy as Number = 0;
    private var mSecFont as FontType = Graphics.FONT_NUMBER_MILD;
    private var mHasSecGeom as Boolean = false;

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
            "arrow-up"   => WatchUi.loadResource(Rez.Drawables.IconArrowUpBlack),
            "arrow-down" => WatchUi.loadResource(Rez.Drawables.IconArrowDownBlack),
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
            "arrow-up"   => WatchUi.loadResource(Rez.Drawables.IconArrowUpWhite),
            "arrow-down" => WatchUi.loadResource(Rez.Drawables.IconArrowDownWhite),
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

    // The bitmap for an icon in the OPPOSITE theme colour, for icons that sit on
    // an inverted (ink-filled) panel — white icons on a black panel in the Light
    // theme, black icons on a white panel in the Dark theme.
    private function iconInverted(name as String) as WatchUi.BitmapResource? {
        var d = (mTheme == 1) ? mIconBlack : mIconWhite;
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
        mShowArc     = propBool("ShowGoalArc", true);
        mShowHrGraph = propBool("ShowHrGraph", false);
        mSlotML      = propNumber("SlotML", 0);
        mSlotMR      = propNumber("SlotMR", 1);
        mSlotLL      = propNumber("SlotLL", 4);
        mSlotLC      = propNumber("SlotLC", 3);
        mSlotLR      = propNumber("SlotLR", 5);
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

        // Always-on (AMOLED) low-power: draw a minimal, dim, burn-in-safe face -
        // just HH:MM in a muted grey on black - to cut lit pixels and save battery.
        if (mLowPower && requiresBurnInProtection()) {
            drawLowPowerFace(dc, w, h, cx);
            return;
        }

        // Clear to background.
        dc.setColor(mBg, mBg);
        dc.clear();

        if (mShowArc) { drawGoalArc(dc, w, h, cx); }
        drawTopCluster(dc, w, h, cx);
        drawTimeCards(dc, w, h, cx);
        drawComplications(dc, w, h, cx);
    }

    // The eclipse ring: a faint full "penumbra" track hugging the bezel, with the
    // portion of today's step goal that's complete lit in the accent colour,
    // sweeping clockwise from 12 o'clock like a shadow crossing the disc.
    private function drawGoalArc(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        var mon = ActivityMonitor.getInfo();
        if (mon == null) { return; }

        var steps = (mon.steps != null) ? mon.steps : 0;
        var goal = 10000;
        if (mon has :stepGoal && mon.stepGoal != null && mon.stepGoal > 0) {
            goal = mon.stepGoal;
        }
        var frac = steps.toFloat() / goal.toFloat();
        if (frac < 0.0) { frac = 0.0; }
        if (frac > 1.0) { frac = 1.0; }

        var cy  = h / 2;
        var pen = (w * 0.022).toNumber();
        if (pen < 3) { pen = 3; }
        var minDim = (w < h) ? w : h;
        var r = minDim / 2 - pen / 2 - (w * 0.010).toNumber();

        dc.setPenWidth(pen);

        // Faint full track (the shadow).
        var track = (mTheme == 1) ? 0x2A2A2A : 0xDCDCDC;
        dc.setColor(track, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);

        // Lit progress arc, clockwise from the top.
        if (frac >= 0.999) {
            dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r);
        } else if (frac > 0.0) {
            // Clockwise from 12 o'clock (90 deg). Keep the end angle in 0..360.
            var endDeg = 90.0 - frac * 360.0;
            if (endDeg < 0.0) { endDeg += 360.0; }
            dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, endDeg.toNumber());
        }

        dc.setPenWidth(1);
    }

    // True on AMOLED panels that need burn-in protection in always-on mode.
    private function requiresBurnInProtection() as Boolean {
        var s = System.getDeviceSettings();
        if (s has :requiresBurnInProtection) {
            return s.requiresBurnInProtection;
        }
        return false;
    }

    // Sleep/wake hooks: track power state and repaint. In low power we stop the
    // per-second update (see onPartialUpdate) and, on AMOLED, switch to the dim
    // minimal face.
    function onEnterSleep() as Void {
        mLowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        mLowPower = false;
        WatchUi.requestUpdate();
    }

    // Retick only the seconds each second while awake. Kept tiny - clip to the
    // seconds glyph, clear it, redraw - to stay inside the partial-update power
    // budget. Skipped in low power so seconds don't tick in always-on.
    function onPartialUpdate(dc as Dc) as Void {
        if (!mShowSeconds || mLowPower || !mHasSecGeom) { return; }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var ss = pad2(System.getClockTime().sec);
        var tw = dc.getTextWidthInPixels(ss, mSecFont);
        var fh = dc.getFontHeight(mSecFont);
        var cw = tw + 8;
        var ch = fh + 4;
        var x0 = mSecCx - cw / 2;
        var y0 = mSecCy - ch / 2;

        dc.setClip(x0, y0, cw, ch);
        dc.setColor(mBg, mBg);
        dc.clear();
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mSecCx, mSecCy, mSecFont, ss,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.clearClip();
    }

    // The minimal always-on face: dim HH:MM centred on black, drifting a few
    // pixels each minute so no pixel stays lit in one spot (burn-in guard).
    private function drawLowPowerFace(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var hhmm = pad2(hour) + ":" + pad2(clock.min);

        var idx = pickNumberFontIndex(dc, "00:00", (w * 0.72).toNumber(), (h * 0.30).toNumber());
        var ox = (clock.min % 6) - 3;            // -3..+2 px horizontal drift
        var oy = ((clock.min / 6) % 6) - 3;      // -3..+2 px vertical drift

        dc.setColor(0x646464, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + ox, (h * 0.50).toNumber() + oy, NUMBER_FONTS[idx], hhmm,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

        // Reserve the seconds slot whenever the setting is on so HH/MM stay put,
        // but only actually paint the seconds while awake - in low power we blank
        // them (they'd only tick per minute) and let onPartialUpdate drive them.
        var reserveSec = mShowSeconds;
        var drawSec    = mShowSeconds && !mLowPower;

        // Card geometry, proportional to the screen.
        var cardH  = (h * 0.175).toNumber();
        var mainW  = (w * 0.225).toNumber();
        var ssW    = (w * 0.135).toNumber();
        var gap    = (w * 0.020).toNumber();
        var radius = (cardH * 0.16).toNumber();

        var totalW = reserveSec ? (mainW * 2 + ssW + gap * 2) : (mainW * 2 + gap);
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

        // Cache the seconds centre + font so onPartialUpdate can retick in place.
        mSecCx = ssX + ssW / 2;
        mSecCy = ssTop + ssH / 2;
        mSecFont = ssFont;
        mHasSecGeom = reserveSec;

        // Main HH / MM cards.
        drawCard(dc, hhX, cardTop, mainW, cardH, radius, hh, mainFont, mInk);
        drawCard(dc, mmX, cardTop, mainW, cardH, radius, mm, mainFont, mInk);

        // Smaller seconds card, vertically centred on the same row.
        if (drawSec) {
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
            dc.setColor(batteryColor(batt.toNumber()), Graphics.COLOR_TRANSPARENT);
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

        // Weather below the date, if available and enabled. The condition icon
        // reflects the actual current sky; the daily high/low are each capped with a
        // caret (up for the high, down for the low).
        if (mShowWeather && (Toybox has :Weather)) {
            var cond = Weather.getCurrentConditions();
            if (cond != null) {
                drawWeatherRow(dc, w, h, cx, cond);
            }
        }
    }

    // The weather row, centred on cx: [condition icon] [current temp]  ^[high]  v[low].
    // The high/low carets sit just above their numbers.
    private function drawWeatherRow(dc as Dc, w as Number, h as Number, cx as Number,
                                    cond as Weather.CurrentConditions) as Void {
        if (cond.temperature == null) { return; }

        var metric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
        var t = cond.temperature.toFloat();          // Celsius
        var hi = cond.highTemperature;
        var lo = cond.lowTemperature;
        if (!metric) {
            t = t * 9.0 / 5.0 + 32.0;
            if (hi != null) { hi = (hi.toFloat() * 9.0 / 5.0 + 32.0).toNumber(); }
            if (lo != null) { lo = (lo.toFloat() * 9.0 / 5.0 + 32.0).toNumber(); }
        }
        var curStr = t.format("%d") + "°";
        var hiStr = (hi != null) ? hi.format("%d") : null;
        var loStr = (lo != null) ? lo.format("%d") : null;

        var font = Graphics.FONT_XTINY;
        var wy   = (h * 0.315).toNumber();
        var gap  = (w * 0.030).toNumber();

        var iconName = (cond.condition != null) ? weatherIconName(cond.condition) : "sun";
        var condBmp  = icon(iconName);
        var condW    = (condBmp != null) ? condBmp.getWidth() : 0;

        var curW = dc.getTextWidthInPixels(curStr, font);
        var hiW  = (hiStr != null) ? dc.getTextWidthInPixels(hiStr, font) : 0;
        var loW  = (loStr != null) ? dc.getTextWidthInPixels(loStr, font) : 0;

        var total = condW + gap + curW;
        if (hiStr != null) { total += gap + hiW; }
        if (loStr != null) { total += gap + loW; }

        var x = cx - total / 2;

        // condition icon
        drawIcon(dc, iconName, (x + condW / 2).toNumber(), wy);
        x += condW + gap;

        // current temperature
        dc.setColor(mText, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, wy, font, curStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += curW;

        // high, capped with an up caret
        if (hiStr != null) {
            x += gap;
            drawTempWithArrow(dc, x, wy, "arrow-up", hiStr, hiW, font);
            x += hiW;
        }
        // low, capped with a down caret
        if (loStr != null) {
            x += gap;
            drawTempWithArrow(dc, x, wy, "arrow-down", loStr, loW, font);
            x += loW;
        }
    }

    // Draw a temperature number left-justified at (x, y) with a caret centred above it.
    private function drawTempWithArrow(dc as Dc, x as Number, y as Number, arrowName as String,
                                       numStr as String, numW as Number, font as FontType) as Void {
        dc.setColor(mText, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, numStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var bmp = icon(arrowName);
        if (bmp != null) {
            var ax = (x + numW / 2 - bmp.getWidth() / 2).toNumber();
            var ay = (y - dc.getFontHeight(font) / 2 - bmp.getHeight() + 4).toNumber();
            dc.drawBitmap(ax, ay, bmp);
        }
    }

    // ===========================================================================
    //  Complication ring
    // ===========================================================================
    private function drawComplications(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        var mon = ActivityMonitor.getInfo();
        var settings = System.getDeviceSettings();

        // Upper flanks: alarms (left), notifications (right). Each sits on an
        // ink-filled panel that runs off the left/right bezel, separating it from
        // the centred weather row and making it easy to read at a glance. Lifted to
        // ~0.30 so the panel's lower edge clears the heart / body-battery icons that
        // sit beside the time cards at ~0.50. Icons/values use the inverted colours.
        drawFlankCell(dc, w, -1, (w * 0.130).toNumber(), (h * 0.30).toNumber(),
                      "alarm", numOrDash(settings.alarmCount));
        drawFlankCell(dc, w, 1, (w * 0.870).toNumber(), (h * 0.30).toNumber(),
                      "bell", numOrDash(settings.notificationCount));

        // Two margin slots beside the digits (widest part of the round screen).
        drawComplicationSlot(dc, (w * 0.085).toNumber(), (h * 0.50).toNumber(), mSlotML, mon, settings);
        drawComplicationSlot(dc, (w * 0.915).toNumber(), (h * 0.50).toNumber(), mSlotMR, mon, settings);

        // Lower band: either the three configurable slots, or - in HR trend mode -
        // a heart-rate sparkline that takes over that strip.
        if (mShowHrGraph) {
            drawHrGraph(dc, w, h, cx);
        } else {
            drawComplicationSlot(dc, (w * 0.275).toNumber(), (h * 0.685).toNumber(), mSlotLL, mon, settings);
            drawComplicationSlot(dc, (w * 0.50).toNumber(),  (h * 0.685).toNumber(), mSlotLC, mon, settings);
            drawComplicationSlot(dc, (w * 0.725).toNumber(), (h * 0.685).toNumber(), mSlotLR, mon, settings);
        }

        // Steps, bottom centre: foot icon above, number below. Kept clear of the
        // bottom bezel.
        var steps = (mon != null) ? mon.steps : null;
        var stepsStr = (steps != null) ? steps.format("%d") : "--";
        drawIcon(dc, "footprint", cx, (h * 0.795).toNumber());
        dc.setColor(mInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.865).toNumber(), Graphics.FONT_MEDIUM, stepsStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A flank complication seated on an ink-filled panel that runs off the bezel.
    // `side` is -1 for the left edge, +1 for the right. The panel is filled with
    // mInk (black on Light, white on Dark); the icon uses the inverted colour set
    // and the value is drawn in mBg so both stand off the panel.
    private function drawFlankCell(dc as Dc, w as Number, side as Number,
                                   cx as Number, cy as Number,
                                   name as String, value as String) as Void {
        var font = Graphics.FONT_XTINY;
        var labelH = dc.getFontHeight(font);

        var bmp = iconInverted(name);
        var iconW = (bmp != null) ? bmp.getWidth() : 0;
        var iconH = (bmp != null) ? bmp.getHeight() : 0;

        var valW = dc.getTextWidthInPixels(value, font);
        var contentW = (iconW > valW) ? iconW : valW;

        var padX   = (w * 0.045).toNumber();
        var padY   = (labelH * 0.40).toNumber();
        var radius = (labelH * 0.5).toNumber();

        // Icon centred just above cy, value just below (matches drawCell).
        var iconCy = (cy - labelH * 0.45).toNumber();
        var textCy = (cy + labelH * 0.55).toNumber();

        var top    = iconCy - iconH / 2 - padY;
        var bottom = (textCy + labelH / 2 + padY).toNumber();

        // Anchor the far edge past the bezel so only the inner corners round.
        var left; var right;
        if (side < 0) {
            left  = 0 - radius;
            right = cx + contentW / 2 + padX;
        } else {
            left  = cx - contentW / 2 - padX;
            right = w + radius;
        }

        dc.setColor(mInk, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, top, right - left, bottom - top, radius);

        if (bmp != null) {
            dc.drawBitmap((cx - iconW / 2).toNumber(), (iconCy - iconH / 2).toNumber(), bmp);
        }
        dc.setColor(mBg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, textCy, font, value,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draw a configurable slot: resolve its data-type id to an icon, value, and
    // (where meaningful) a semantic tint, then render it like any other cell.
    private function drawComplicationSlot(dc as Dc, x as Number, y as Number, type as Number,
                                          mon as ActivityMonitor.Info or Null,
                                          settings as System.DeviceSettings) as Void {
        var name = "";
        var value = "--";
        var color = mText;

        if (type == DATA_HR) {
            var hr = getHeartRate();
            name = "heart"; value = numOrDash(hr);
            if (hr != null) { color = heartColor(hr); }
        } else if (type == DATA_BB) {
            var bb = getBodyBattery();
            name = "bolt"; value = percentOrDash(bb);
            if (bb != null) { color = bodyBatteryColor(bb); }
        } else if (type == DATA_STEPS) {
            name = "footprint";
            value = (mon != null && mon.steps != null) ? mon.steps.format("%d") : "--";
        } else if (type == DATA_CALORIES) {
            name = "flame";
            value = numOrDash(mon != null ? mon.calories : null);
        } else if (type == DATA_DISTANCE) {
            name = "route"; value = distanceString(mon, settings);
        } else if (type == DATA_FLOORS) {
            name = "stairs"; value = floorsString(mon);
        } else if (type == DATA_ALARMS) {
            name = "alarm"; value = numOrDash(settings.alarmCount);
        } else if (type == DATA_NOTIFS) {
            name = "bell"; value = numOrDash(settings.notificationCount);
        } else {
            return;  // DATA_NONE (or unknown): leave the slot empty
        }

        drawCellColored(dc, x, y, name, value, color);
    }

    // A complication cell: icon on top, value below, centred on (x, y), the value
    // drawn in the given colour (mText for a plain cell, or a semantic tint).
    private function drawCellColored(dc as Dc, x as Number, y as Number, name as String,
                                     value as String, color as Number) as Void {
        var labelH = dc.getFontHeight(Graphics.FONT_XTINY);
        drawIcon(dc, name, x, (y - labelH * 0.45).toNumber());
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + labelH * 0.55, Graphics.FONT_XTINY, value,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Heart-rate sparkline across the lower band. Samples come from SensorHistory
    // (newest first); we draw them oldest->newest, left to right - thin, tinted by
    // the latest zone, over a faint baseline, with a dot on the current reading.
    private function drawHrGraph(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        if (!(Toybox has :SensorHistory) || !(Toybox.SensorHistory has :getHeartRateHistory)) {
            return;
        }
        var it = Toybox.SensorHistory.getHeartRateHistory(
                    {:period => 64, :order => Toybox.SensorHistory.ORDER_NEWEST_FIRST});
        if (it == null) { return; }

        var vals = [] as Array<Number>;
        var s = it.next();
        while (s != null && vals.size() < 64) {
            if (s.data != null) { vals.add(s.data.toNumber()); }
            s = it.next();
        }
        var n = vals.size();
        if (n < 2) { return; }

        // Vertical range for scaling.
        var lo = vals[0];
        var hi = vals[0];
        for (var i = 1; i < n; i++) {
            if (vals[i] < lo) { lo = vals[i]; }
            if (vals[i] > hi) { hi = vals[i]; }
        }
        var span = hi - lo;
        if (span < 1) { span = 1; }

        var gw = (w * 0.52).toNumber();
        var gh = (h * 0.085).toNumber();
        var gx = cx - gw / 2;
        var gy = (h * 0.64).toNumber();

        // Faint baseline.
        dc.setPenWidth(1);
        dc.setColor((mTheme == 1) ? 0x2A2A2A : 0xDCDCDC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(gx, gy + gh, gx + gw, gy + gh);

        // Line colour follows the latest zone; stays visible (accent) at rest.
        var lineCol = heartColor(vals[0]);
        if (lineCol == mText) { lineCol = mAccent; }

        dc.setPenWidth(2);
        dc.setColor(lineCol, Graphics.COLOR_TRANSPARENT);

        var prevX = 0;
        var prevY = 0;
        for (var i = 0; i < n; i++) {
            var v = vals[n - 1 - i];               // oldest first, left to right
            var px = gx + (gw * i) / (n - 1);
            var py = gy + gh - ((v - lo) * gh) / span;
            if (i > 0) { dc.drawLine(prevX, prevY, px, py); }
            prevX = px;
            prevY = py;
        }

        // Dot on the current reading (right end).
        dc.fillCircle(prevX, prevY, (w * 0.012).toNumber());
        dc.setPenWidth(1);
    }

    // ---- Semantic colour helpers ----------------------------------------------
    // Shared status palette (kept independent of the accent so meaning stays fixed).
    private const COL_GOOD = 0x2EA84F;   // green
    private const COL_WARN = 0xF2A100;   // amber
    private const COL_BAD  = 0xE23B2E;   // red
    private const COL_INFO = 0x2E7DE0;   // blue

    // Device battery: amber under 25%, red under 10%, otherwise the muted default.
    private function batteryColor(pct as Number) as Number {
        if (pct <= 10) { return COL_BAD; }
        if (pct <= 25) { return COL_WARN; }
        return mMuted;
    }

    // Body Battery: green when charged, amber mid, red when depleted.
    private function bodyBatteryColor(v as Number) as Number {
        if (v >= 50) { return COL_GOOD; }
        if (v >= 25) { return COL_WARN; }
        return COL_BAD;
    }

    // Heart rate tinted by broad zone using fixed thresholds (roughly a 190 bpm
    // max HR). Kept threshold-based so the face needs no UserProfile permission;
    // below zone 2 it stays neutral (mText).
    private function heartColor(hr as Number) as Number {
        if (hr >= 171) { return COL_BAD; }   // zone 5
        if (hr >= 152) { return COL_WARN; }  // zone 4
        if (hr >= 133) { return COL_GOOD; }  // zone 3
        if (hr >= 114) { return COL_INFO; }  // zone 2
        return mText;                        // zone 1 / rest
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
