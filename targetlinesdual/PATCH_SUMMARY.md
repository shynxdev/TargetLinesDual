# TargetLinesDual 0.1.1-test — changes from 0.1.0

Applied `01-cyan-only.patch`, `02-renderer-safety.patch`, and `03-lifecycle-safety.patch`, in that order, to a fresh copy of the audited 0.1.0 candidate. The tested 0.1.1-test source published in this repository is under `targetlinesdual/`.

## Scope correction

- Deleted the added persistent red renderer, its color/width/enabled settings and the optional duplicate toggle.
- Restored the original action filter expression (`s.filters == 'Alliance'`) rather than silently changing the original Alliance behavior.
- Removed the remaining `ffxi.targets`/`get_bt` dependency and warning code after applying patch 01. The revised request calls for current selection independently of battle state; there is no original persistent red line to deduplicate against. An active selected entity may therefore receive cyan while engaged, including the same entity being fought.
- Exactly one overlay call uses slot 0 (the current target or active sub-target). No scan of all entities occurs in the frame/selection path.
- Changed version metadata to `0.1.1-test` and replaced the obsolete submission documentation. No red replacement was invented.

## Concrete safety changes

- Login, active local-player slot, zone and character identity gates clear cached action records. Cyan has no retained target state to clear.
- Check current target slot server ID and actor pointer against the entity manager; recheck identity after collecting positions. Dead/despawned/invalid selections do not render.
- Validate numeric index bounds, actor/skeleton pointer sanity, bone bounds, coordinate finiteness and identity stability. Invalid skeletons now return no coordinates, instead of patch 03's fallback body position. A shared `getActorPoint` keeps the original bone-2/vertical-midpoint formula and makes all original action branches handle unavailable coordinates safely. It reuses the base Z read rather than reading it again.
- Action packets reject unresolved/unloaded endpoints and store server IDs. Reused source/target indices cannot inherit a previous entity's action timing. Existing normal repeat-action and type-4 timing behavior is retained, including actions changing target.
- Death packets read Target Index at `0x16`, not Actor Index at `0x14`, and also match the packet's target server ID. All affected arcs use their own existing half-second fade. A late death message cannot expire a new entity reusing the slot.
- Reuse the existing incoming packet hook for zone entry/exit. Ignore unrelated packet IDs before new lifecycle lookups. Add size checks for action/death packet reads, expire records outside the visible filter, and clear session-bound records. A first action in the new zone is not erased again by the frame callback.
- Refresh both config/render settings references on reload and character changes. Validate only the selected-overlay settings; keep original filter semantics and saved original-addon files intact.
- Construct and validate vertices before locking the D3D buffer. Upload through a protected copy with an unlock after success or Lua copy failure. A successful lock with a null pointer also unlocks. Failed lock/allocation/unlock or missing textures do not draw.
- Release the vertex buffer and both textures exactly once on unload, detaching texture finalizers before explicit release.
- Correct table-versus-number clipping, linear roots, empty clipping intervals, shared Bezier control-point ownership and zero-length normalization. Reject coincident/nonfinite inputs and undefined homogeneous projection before writing geometry. A failed transform/initial viewport query hides drawing instead of indexing nil.

## Preserved behavior and boundaries

Original timed action colors, timeouts, animations, arc direction, normal geometry and default width remain in place. Valid-action and red-vertex comparisons are recorded in the test results. Safety corrections intentionally change previously invalid/death/session behavior.

Original incoming action ID resolution still has a bounded entity-table fallback. It runs in response to an action packet, not every frame; altering that original algorithm was unnecessary. Frame work consists of the existing action traversal plus a constant number of current-selection lookups and at most one cyan geometry build. No native frame-rate benchmark was performed.

The original viewport cache, broad endpoint culling, one-endpoint clipping approach and depth-disabled drawing are not redesigned. These are inherited visual/integration limitations, disclosed in the audit. An arbitrary plausible nonzero pointer can still be unmapped; sanity/identity checks do not prove native memory safety. No live client or staff approval is claimed.

The complete published 0.1.1-test source includes all corrections described above. The three earlier review patches alone do not include the further refinements made during the final audit, so use this repository's complete source when reviewing this version.
