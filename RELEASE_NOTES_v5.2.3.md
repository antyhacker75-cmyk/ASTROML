# ASTROML v5.2.3

## New features
- Added adjustable app-wide text size in Settings, with a live preview, saved preference, and reset option.
- Restored and refreshed the System Restore Environment card with clearer environment status indicators.
- Added a Shizuku connection status badge so the bound/ready state is easier to notice.
- Expanded the Change Logs view to load up to 100 published GitHub releases.

## Improvements
- Updated the Settings and System Restore presentation with clearer status styling, spacing, and visual hierarchy.
- Update notifications now request the same in-app update dialog used by the manual update checker, including release notes and the Download update action.
- Kept the release notes inside the update dialog while removing the separate notification-tap release-notes popup.
- Added support for stable and beta release labels such as `5.2.3`, `5.2.3-beta`, `5.2.3-beta1`, and `5.2.3-beta2` in the release workflow.

## Fixes
- Fixed Android DownloadManager ID handling to avoid the Integer-to-Long cast crash.
- Replaced deprecated `COLUMN_LOCAL_FILENAME` access with the downloaded content URI flow for newer Android versions.
- Enabled visible DownloadManager progress notifications during APK downloads.
- Removed an unused Dart import that caused `flutter analyze` to report a warning.
- Improved Shizuku status handling so an already-bound service is not incorrectly shown as needing a fix.

## Notes
- APK installation still requires Android's install-unknown-apps permission to be allowed for ASTROML.
- Release notes shown by the updater are taken from the published GitHub Release body.
