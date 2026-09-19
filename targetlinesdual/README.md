# TargetLinesDual 0.1.1-test

Original TargetLines timed action lines plus one current-selected-target/sub-target overlay, defaulting to thin cyan. Based on Jyouya's TargetLines commit `709ad39087a4fdfd47775050d55773b0e0eb7615` (version 1.2).

This is an offline-checked test build, not a HorizonXI approval claim. No live HorizonXI client testing has been performed.

The added persistent red battle-target renderer has been removed completely. The cyan feature does not query battle targets or consult action-line/red settings. While engaged, the current selected target can have a cyan line even when it is the target being fought. Original timed action lines render independently and can coexist with cyan. The addon never draws a second cyan line for the normal target behind a sub-target cursor.

Cyan requires a current active selection whose index, server ID and actor pointer agree with the loaded entity. It disappears on target clear, invalid/missing skeleton, stale entity identity, player/target death, zoning and logout. Dead targets, including Raise targets, intentionally receive no cyan line in this version. Self-selection and coincident endpoints produce no line. No selected entity or line object is retained across frames.

Keep the directory named `targetlinesdual`. For an authorized Ashita test environment, load with `/addon load targetlinesdual` and open configuration with `/tld` or `/targetlinesdual`. Do not load original TargetLines simultaneously: this addon already includes its action renderer. This README is not authorization to run the fork on HorizonXI.

Settings retain the original action filter and the selected-overlay enabled/color/width controls. Cyan defaults to `0xFF00C8FF` with width parameter `2.0`; original action calls retain width parameter `3`. The user's saved selected-overlay color/width may override these defaults. Old persistent-battle and duplicate-toggle settings are unused. Existing original TargetLines settings are not overwritten or automatically imported; select the same action filter manually when comparing builds. Reload/character changes refresh the active settings references.

The upstream Alliance-filter expression is deliberately preserved, including its existing typo: with ordinary settings, Alliance behaves like Party. Fixing that unrelated behavior would change the action lines this build is intended to preserve.

Safety changes and offline checks are documented in `PATCH_SUMMARY.md` and the accompanying `AUDIT-0.1.1-test.md`. Original action colors, timing and valid-geometry output are preserved in tested cases; invalid-entity, death, clipping-error and session cleanup behavior is intentionally corrected.

The renderer inherits depth-disabled drawing, so arcs may overlay world geometry. It also retains upstream viewport caching and clipping limitations. Native pointer safety, driver/device-loss behavior and visual compatibility still require client validation. If vertex-buffer creation fails, rendering remains hidden until addon reload.

Original author: Jyouya. The pinned source tree did not include a license file. Confirm redistribution permission before publishing the fork. No packet sending/injection, gameplay automation, target modification or input simulation is implemented.
