# E2E / Manual Test Guide

The Swift package's `swift test` target covers reducers and models. `LaunchpadUITests.swift`
is not wired to an Xcode UI-testing target in this repository, so actual window and drag/drop
behavior still needs manual verification on macOS.

## Important: preferences are persistent

The app stores preferences in `UserDefaults`, not `~/Library/Application Support/Launchpad`.
The smoke-test scripts intentionally do not delete user data. UI actions such as creating folders
or renaming apps can persist in the current preference domain. Use a separate macOS test account
if you need an isolated run.

## Launch

```bash
swift build
.build/debug/Launchpad
```

For the packaged app, run `./build-app.sh` and then `open build/Launchpad.app`.

## Search and folders

1. Search for an app that is not in a folder and verify case-insensitive matching.
2. Rename an app, then search by its custom name.
3. Put an app in a folder, then search for it from the main grid; it should remain findable.
4. Search for a folder name and open the matching folder.
5. Remove the app from the folder and verify it returns to the main grid.

## Drag and drop

- In normal mode, drag an app onto another app: nothing should happen (classic
  Launchpad ignores drags outside edit mode; order must not change).
- Enter Edit Mode via the toolbar pencil button, a long-press on an icon, or by
  holding Option (release Option to leave). Icons should jiggle while editing.
- In Edit Mode, drop an app on another icon's center to create a folder with both;
  drop on its leading/trailing edge to reorder before/after it.
- Drag an app onto a folder to add it; it should disappear from the main grid.
- Drag a folder onto another folder (Edit Mode) to reorder them.
- Open a folder and drag an app onto another item inside to reorder; drag it onto
  the dim backdrop to remove it from the folder. Removing the last app deletes
  the folder and closes the modal.
- Verify the dragged item opacity and drop-target indicator clear after a drop.
- Restart the app and verify order and folder membership persist.

## Launch, keyboard, and auto-refresh

- Click an app (main grid or inside a folder) and verify the app launches, the
  folder modal closes, and Launchpad hides itself.
- With the main grid focused: arrow keys move the selection ring, Enter launches
  the selected app (or opens the selected folder), Enter with no selection
  launches the first app. Arrows are ignored while typing in search.
- Install or remove an app in /Applications while Launchpad is open and verify
  the grid refreshes by itself within a couple of seconds (no Refresh needed).
- In Edit Mode, only Mac App Store apps show the red minus badge; other apps can
  still be moved to Trash from the right-click menu.

## Folder dismissal and settings

1. Open a folder and dismiss it with the Close button, Escape, and a click outside the folder panel.
2. Open and close a folder repeatedly; verify the UI remains responsive.
3. Change icon size, columns, and Show hidden apps in Settings. Verify layout, icon sharpness,
   and app visibility update without resetting folders or custom names.

## Automated checks

- `swift test` runs the package unit tests.
- `tests/test-launch.sh` is a manual smoke test; it builds and launches the app and prints process
  resource usage.
- `tests/run-e2e-test.sh` requires Accessibility permission and provides limited AppleScript
  diagnostics. It is not a substitute for the manual checks above.
