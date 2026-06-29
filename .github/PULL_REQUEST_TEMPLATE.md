<!-- Thanks for contributing to Penumbra! -->

## Description

<!-- What does this PR change and why? Link any related issue, e.g. "Closes #12". -->

## Type of change

- [ ] Bug fix
- [ ] New feature (complication, theme, accent, indicator, etc.)
- [ ] Layout / readability improvement
- [ ] New device support
- [ ] Icon / asset update
- [ ] Documentation
- [ ] Other:

## Devices tested

- [ ] `fenix847mm` (454×454 AMOLED, primary target)
- [ ] A smaller MIP panel (e.g. `fenix7`, 260×260)
- [ ] Other:

## Checklist

- [ ] `./build.ps1 -Device <device>` compiles with no errors
- [ ] `./build.ps1 -Export` builds the store package (.iq) for all manifest devices
- [ ] Verified the change in the Connect IQ simulator (`./build.ps1 -Device <device> -Run`)
- [ ] Checked both **Light** and **Dark** themes
- [ ] No clipping at the round bezel; complications degrade gracefully to `--`
- [ ] If icons changed: re-ran `python tools/prep_icons.py` and registered both colour variants
- [ ] Settings still load and sanitize correctly (theme, accent, toggles)

## Screenshots

<!-- Before/after simulator screenshots for any visual change. -->
