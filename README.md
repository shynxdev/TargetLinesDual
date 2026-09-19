# TargetLinesDual

TargetLinesDual is a fork of [Jyouya/targetlines](https://github.com/Jyouya/targetlines) that keeps the original timed action-line behavior and adds one isolated cyan current-target/sub-target line.

## Status

Current public test build: **0.1.1-test**

This is an offline-tested development build and **is not a claim of HorizonXI approval**.

The exact submitted test ZIP has SHA-256:

`782a19e84774fd128101d8a86ebf4b660cd0912623278513aaf38e8eec9d52f2`

Offline test result reported for this build: **291 passed, 0 failed**.

No live HorizonXI client testing was performed before publication.

## What changes

- Preserves the original TargetLines timed action lines.
- Adds one cyan line for the current selected target / active sub-target.
- Removes the experimental persistent red battle-target overlay from the earlier candidate.
- Adds entity, lifecycle, renderer, cleanup, and settings-safety fixes.
- Removes the added per-frame scan of up to 2,303 entities.
- Does not send or inject packets.
- Does not automate targeting, movement, combat, commands, actions, or input.

See `targetlinesdual/PATCH_SUMMARY.md` for the detailed scoped changes.

## Source layout

The exact `0.1.1-test` addon source from the tested ZIP is kept under:

`targetlinesdual/`

The directory name should remain `targetlinesdual` when installed in an authorized Ashita environment.

## Attribution and permission

Original TargetLines author: **Will / Jyouya**

Original project: https://github.com/Jyouya/targetlines

TargetLinesDual is a modified fork. On **September 17, 2026**, the original author gave SHYNX explicit permission by email to fork TargetLines.

The upstream repository did not include a license file, so this repository does **not** add a new blanket license over the inherited TargetLines code.

The original author also noted that a major TargetLines update for **Ashita 4.4** is planned. This test build should be revalidated against that upstream update when it is released.

## HorizonXI

This repository exists so the modified source can be reviewed openly.

Publication here does not mean HorizonXI has approved the addon. Follow HorizonXI staff guidance before loading or using the fork on the live server.
