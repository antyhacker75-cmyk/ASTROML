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


## ASTROML 5.2.7-beta15

Developer: **Astro Renz**

### Downloads
- **ARM32** — for 32-bit ARM devices.
- **ARM64** — for 64-bit ARM devices.
- **Universal** — APK containing the supported target ABIs.

### Release notes and screenshots

#### Added
- Added a dedicated **Boosters** section beside Cosmetics.
- Added booster search using the name and description.
- Added search bars to the Cosmetics categories.
- Added support for loading booster entries from `boosters.txt` with name, description, image, and `sc` fields.

#### Changed
- Updated the release notes reader to accept multiple compatible description fields.
- Updated updater download handling to remove previous ASTROML updater downloads before saving a replacement, preventing duplicate APK copies from accumulating.

#### Fixed
- Fixed duplicate ASTROML update APK files appearing in the app-specific Download folder after repeated downloads.

### Release notes and screenshots
Add release notes below. To display up to two screenshots in the app's update dialog, add public HTTPS image links using Markdown:

![ASTROML Banner](https://raw.githubusercontent.com/antyhacker75-cmyk/ASTROML/master/banner.jpg)
