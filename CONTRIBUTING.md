# Contributing to Penumbra

Thanks for your interest in improving Penumbra! It's a bright, data-dense digital
Garmin Connect IQ watch face for round watches, written in
[Monkey C](https://developer.garmin.com/connect-iq/monkey-c/). Contributions of all
kinds are welcome — bug reports, layout/styling improvements, new complications,
device support, icon art, and documentation.

By participating in this project you agree to abide by our
[Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Report a bug** — open a [bug report](../../issues/new?template=bug_report.yml). Please include your device, firmware version, and the SDK version you used.
- **Request a feature** — open a [feature request](../../issues/new?template=feature_request.yml).
- **Submit a change** — fork, branch, and open a pull request (see below).

## Development setup

### Prerequisites

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) **9.1.0+** (install the Fenix 8 device profiles via the **SDK / Device Manager**).
- **Java 17+** (Java 21 is what `build.ps1` defaults to).
- **PowerShell** (the build script is PowerShell-based).
- **Python 3** — only needed if you re-prepare the icon SVGs (`python tools/prep_icons.py`).
- A Connect IQ **developer key** (`developer_key.der`) in the repo root. Generate one with:
  ```powershell
  openssl genrsa -out developer_key.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
  ```
  This file is git-ignored and must **never** be committed.

### Build

```powershell
# Compile for a specific device (defaults to fenix847mm / 454x454)
.\build.ps1 -Device fenix847mm

# Compile and launch in the simulator
.\build.ps1 -Device fenix847mm -Run

# Package a store-ready .iq bundle (all products in the manifest)
.\build.ps1 -Export
```

On first run, `build.ps1` writes a `build_config.json` (git-ignored) with your local
`JavaHome` and `SdkDir` paths — edit it to match your machine.

## Project layout

- `source/App.mc` (`PenumbraApp`) / `source/View.mc` (`PenumbraView`) — the app + watch face. All rendering is procedural in `onUpdate`. (The filenames `App.mc` / `View.mc` are required by the CI file check.)
- `resources/` — strings, settings (theme / accent / toggles), drawables, and the launcher icon.
- `resources/drawables/` — the complication icons (`name-black.svg` / `name-white.svg`) plus the launcher icon, registered in `drawables.xml`.
- `assets/icons/` — the **source** icon SVGs. `tools/prep_icons.py` copies them into `resources/drawables/` (strips the BOM, sets a crisp raster size). Edit SVGs here, then re-run the script.
- `monkey.jungle` — a single `resources` path; everything scales relative to screen size, so there are no per-resolution asset sets.

## Icons

Complication icons are SVG bitmaps. Garmin **can't recolour a bitmap at runtime**, so
each icon ships in two variants — `name-black.svg` (used by the Light theme) and
`name-white.svg` (used by the Dark theme). To add or change an icon:

1. Drop the black + white SVGs in `assets/icons/` (single solid fill, basic
   shapes/paths/strokes only — no gradients, filters, `<text>`, or CSS classes; square
   `viewBox`).
2. Run `python tools/prep_icons.py`.
3. Register both variants in `resources/drawables/drawables.xml` as
   `IconNameBlack` / `IconNameWhite`, load them in `loadIcons()`, and draw with
   `drawIcon(dc, "name", ...)`.

## Testing your changes

Penumbra's primary target is the **fenix 8 47mm** (`fenix847mm`, 454×454 AMOLED), but it
scales across the full round device range. Please check in the simulator:

- Layout holds with **no clipping** at the round bezel — especially the side and corner
  complications.
- Both **Light and Dark** themes render correctly (icons swap black/white).
- Complications fill from live data and **degrade gracefully** to `--` when a sensor or
  weather isn't available (Settings → Battery / Heart Rate / Weather in the sim).
- The **weather condition icon** matches the simulated condition (Settings → Weather).
- `savescreenshot.ps1` captures a clean shot (run it under **Windows PowerShell 5.1**).

## Coding guidelines

- Match the existing style in `source/View.mc`: 4-space indentation, explicit type
  annotations on method signatures, and `private var` for fields.
- Keep drawing **procedural** — size everything relative to `dc.getWidth()` /
  `dc.getHeight()` and the screen center, never hard-coded pixel coordinates, so layouts
  hold across the supported device range.
- Guard optional APIs with `has` checks (e.g. `SensorHistory has :getBodyBatteryHistory`,
  `Toybox has :Weather`) so missing data never crashes the face.
- Theme colours are resolved in `resolveTheme()`; complication anchors are the percentage
  values in `drawComplications()`.
- New user settings go in `resources/settings/` (properties + settings) with a matching
  label in `resources/strings/strings.xml`.

## Pull request process

1. Fork the repo and create a topic branch off `main` (e.g. `feature/sleep-complication` or `fix/notif-icon-clip`).
2. Make your change and confirm it **builds clean** (`.\build.ps1`) and runs in the simulator.
3. Fill out the pull request template, including the devices you tested and before/after screenshots for any visual change.
4. Keep PRs focused — one logical change per PR is easier to review.

### Commit messages

Short, imperative summaries are preferred, optionally using
[Conventional Commits](https://www.conventionalcommits.org/) prefixes:

```
feat: add a sleep complication
fix: keep the notification icon from clipping on the 280 panel
docs: document the icon SVG pipeline
```

## Questions

Open a discussion or file an issue. Thanks for contributing!
