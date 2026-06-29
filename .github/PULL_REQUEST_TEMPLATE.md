<!-- Thanks for contributing to the Binary Watch Face! -->

## Description

<!-- What does this PR change and why? Link any related issue, e.g. "Closes #12". -->

## Type of change

- [ ] Bug fix
- [ ] New feature (data field, theme, grid mode, indicator, etc.)
- [ ] Layout / readability improvement
- [ ] New device support
- [ ] Art / asset update
- [ ] Simulator (app.js / index.html) change
- [ ] Documentation
- [ ] Other:

## Devices tested

- [ ] `fenix7` (MIP, always-on)
- [ ] `venu3` / `epix2` (AMOLED, burn-in protection)
- [ ] Other:

## Checklist

- [ ] `./build.ps1 -Device <device>` compiles with no errors
- [ ] `./build.ps1 -Export` builds the store package (.iq) for all manifest devices
- [ ] Verified the change in the Connect IQ simulator (`./build.ps1 -Device <device> -Run`)
- [ ] Checked both BCD and Pure Binary grid modes
- [ ] Checked always-on / AOD (seconds tick, burn-in shift, dimmed dots)
- [ ] Settings still load and sanitize correctly (themes, data slots, grid mode)
- [ ] Updated the simulator (`app.js`) if device rendering logic changed, to keep parity

## Screenshots

<!-- Before/after simulator screenshots for any visual change. -->
