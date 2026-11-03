# ASTROML Changelog

## Upcoming update system improvements
- Moved automatic update checking to an app-level manager so it runs after startup without opening Settings.
- Routed foreground, background, and terminated-state Firebase notification interactions to the same custom update dialog.
- Changed release notification copy to “Version X is ready. Tap to update.”
- Added a startup check fallback and a throttled check when the app returns to the foreground.
- Prevented duplicate update dialogs from overlapping notification and automatic-check events.

## Android storage compatibility patch
- Android 10 and below now report Shizuku as not required and use the existing direct extraction strategy.
- Older Android versions request the legacy READ/WRITE external-storage runtime permissions instead of opening the Android 11+ all-files-access settings page.
- System Restore now labels Shizuku as not required on Android 10 and below.
- SAF folder selection is not included in this patch yet; the current extraction engine writes through filesystem paths, so SAF needs a DocumentFile/URI-based extraction path before it can safely serve as an injection destination.

## Update installer persistence fix
- Persist the completed APK URI and release version locally.
- Restore the pending APK after returning from Android's Install unknown apps settings.
- Preserve the downloaded APK during update checks when the latest release version is unchanged.
- Clear the saved APK reference when a newer release replaces it or no update is available.
