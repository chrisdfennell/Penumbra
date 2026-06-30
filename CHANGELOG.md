# Changelog

All notable changes to Penumbra are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-06-30

### Changed
- **Alarm and notification complications** moved down into the open flank space, centred
  between the weather line and the time cards, so they no longer crowd the date/weather
  header.
- **Launcher icon** redrawn as the Penumbra eclipse (a light/shadow split disc with an
  accent rim) — matching the store branding, and built from shapes only so it rasterises
  cleanly in CI.

## [1.0.0] - 2026-06-29

### Added
- **Initial release of the Penumbra watch face** — a bright, data-dense digital face,
  fully procedural and scaled to every Connect IQ 4.0+ round panel.
- **Big digital time**: large HH MM groups with the seconds set a tier smaller in the
  accent colour.
- **Light and Dark themes**: white background / black digits, or black background /
  white digits, switchable in settings (defaults to Light).
- **Selectable accent colour** for the seconds: Orange, Blue, Green, Red, or Yellow.
- **Full complication ring with SVG icons**: heart rate, Body Battery, device battery,
  steps, distance (mi/km to match watch units), calories, floors climbed, alarms, and
  notifications.
- **Live weather**: current temperature and daily high/low, plus a condition icon that
  reflects the actual sky — sunny, partly cloudy, cloudy, rain, snow, thunderstorm,
  windy, fog, or wintry mix. The full Garmin Weather condition set (50+ values) is
  mapped down to these icons.
- **Date** with automatic AM/PM when the watch is set to 12-hour time.
- **Settings**: toggles for seconds, date, and weather, plus theme and accent pickers.
- **Broad device support**: Forerunner, fenix / epix / enduro, Venu / vivoactive,
  Instinct, and the Approach / Descent / D2 / MARQ specialty watches. Square/rectangular
  panels are excluded (the layout is designed for round screens).
- **Resolution-independent**: laid out relative to screen size, with the big digits
  using the built-in numeric system fonts — a single resource set scales across all
  supported panels with no per-resolution font assets.
- **Safe degradation**: every sensor / phone-dependent value (heart rate, Body Battery,
  weather) is guarded at runtime and shows a dash until data is available.
