# Project Review and Verification

This report records the current implementation and verification. Unit tests and packaging checks
were run, but interactive GUI behavior still needs a manual macOS run.

## Fixed in this review

- Scanner cache results now carry immutable visibility, raster-size, force-refresh, and display-epoch
  metadata. Waiters no longer inspect mutable metadata belonging to a later scan. Empty scan results
  are cached too.
- Screen-scale checks run before scan-cache reuse, and `IconCache` is synchronized before new icons
  are requested. This closes the notification-order race that could leave stale-resolution icons in
  the grid.
- Global search now finds apps contained in folders and matches custom app names. Folder names are
  also filtered into search results.
- Startup normalization now removes duplicate app-order IDs, duplicate folder identities, and
  duplicate/cross-folder app memberships, while preserving IDs omitted by a visibility-filtered scan
  so hidden apps keep their saved positions and folder assignments. Normalization is persisted even
  when the app order itself was already valid.
- Folder drops end drag visuals, empty-grid drops clear the active-drag state, and creating a folder
  clears a stale search that would otherwise hide it. Edit-mode removal indicators open the Trash
  confirmation dialog; successful Trash operations run off the main thread and remove saved order and
  folder membership.
- Error-banner timer cancellation no longer dismisses a replacement error. Invalid/no-op folder
  actions avoid unnecessary preference writes.
- Preference fields decode independently, so one field with a malformed type does not discard valid
  settings.
- Installer replacement is staged with a backup/restore path and now defaults to the per-user
  `~/Applications` directory, avoiding a guaranteed permission failure for non-root installs. The
  destination can be overridden with `LAUNCHPAD_INSTALL_DIR`. Build/install scripts no longer delete
  user data, the redundant release build was removed from the launch smoke test, and process checks
  no longer match the test shell itself.
- App bundle discovery now resolves `~/Applications` at scan time, reports enumeration failures,
  and avoids caching partial results when a scan is cancelled.
- Icon cache keys include app-bundle metadata (bundle/Info.plist/icon-resource fingerprint), with
  Info.plist icon-name parsing memoized per bundle and invalidated by modification date. Memory-pressure
  handling releases icons held by grid state; visible icons reload lazily via `AppIconView`, keyed by
  app identity so reused cells never show a previous app's bitmap. Settings ranges now match the model's
  accepted ranges.
- The packaged app is intentionally not App Sandbox-enabled so it can discover user-installed apps
  and move user-owned apps to Trash. This gives the app the current user's normal filesystem access;
  `SECURITY.md` documents the trade-off.
- Homebrew instructions now use the explicit repository URL. The formula is documented as
  development-only until an immutable tagged release is published.

## Classic-Launchpad parity pass (10 items)

- Folder modal closes on successful launch; the app also hides itself so the
  launched app comes forward. Failed launches keep the modal open for retry.
- New installs/uninstalls in the app directories are picked up automatically via
  an O_EVTONLY directory observer (debounced) + silent rescan; no manual refresh.
- Normal-mode drags onto apps are ignored (no more accidental reorders). Edit-mode
  drops use the drop point: icon center merges into a folder, edges reorder
  before/after (`moveAppBefore`).
- Intra-folder drag reorder (`moveAppInFolderAfter/Before`); drag-out onto the
  backdrop removes the app; folders can be reordered by dragging tiles in edit
  mode (`moveFolderAfter/Before`). Empty folders auto-delete (also when trashing
  empties one).
- Edit-mode delete badge now shows only for Mac App Store apps (`_MASReceipt`
  detection); context-menu Trash remains for all apps. Folders get their own
  delete badge in edit mode.
- Edit-mode entry: toolbar pencil button (replacing the cryptic sort arrows),
  long-press on an icon, or holding Option; icons jiggle while editing.
- Keyboard: arrows move a selection ring (row-aware via column count), Enter
  launches the selection or first hit; arrows yield to the caret while searching.
- Removed the static "Device" bottom label.

## Verification performed

- `swift test`: **74 tests passed**, 0 failures.
- `swift build -c release`: passed with no compiler warnings.
- `./build-app.sh`: produced an app bundle; strict code-signature verification and Info.plist
  validation passed. The signature has no App Sandbox entitlement. The app itself was not launched.
- Installer replacement was exercised against a temporary `LAUNCHPAD_INSTALL_DIR` destination;
  the new app installed successfully, strict signature verification passed, and no staging/backup
  directories were left behind.
- `bash -n` and `shellcheck`: passed for all shell scripts.
- `ruby -c Formula/launchpad.rb`: passed.
- `osacompile`: passed for `tests/e2e-test.applescript`.

The unit suite currently emits benign TCA `XCTExpectFailure` diagnostics when tests cancel pending
preference-save effects with `skipInFlightEffects`; the test suite still reports zero failures.

## Remaining verification / performance considerations

- The GUI smoke test and folder-background dismissal were not run in this session because they require
  an interactive desktop and, for the AppleScript helper, Accessibility permission.
- The repository has no Xcode UI-testing target/project, and `LaunchpadUITests.swift` is excluded from
  `swift test`; those tests are currently not part of automated verification.
- App discovery still rasterizes icons for every discovered app during a scan before the initial grid
  appears. The scan is bounded to eight concurrent app tasks and cached in-process, so a very large
  app collection can still increase initial scan time. Under memory pressure, the grid now drops those
  strong references (`memoryPressureReceived`) and `AppIconView` reloads icons lazily as cells become
  visible; `NSCache`'s 100 MB cost limit still does not bound `NSImage`s strongly held by the
  scanner/store between pressure events. A fully lazy visible-only scan remains future work.
- Move to Trash works subject to normal POSIX permissions and System Integrity Protection; protected
  apps may still need to be moved with Finder or an administrator-authorized workflow.
- The repository has no tagged immutable Homebrew release yet. The formula tracks `main` and should
  only be presented as a development/HEAD install until a release archive and checksum are published.
