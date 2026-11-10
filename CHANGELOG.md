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


## ASTROML 5.2.7-beta16

Developer: **Astro Renz**

### Downloads
- **ARM32** — for 32-bit ARM devices.
- **ARM64** — for 64-bit ARM devices.
- **Universal** — APK containing the supported target ABIs.

### Release notes

#### Added
- Added booster injection using the existing ASTROML download and extraction engine.
- Added persistent injected-state tracking for boosters.
- Added an Inject button with progress and completion states to each booster card.
- Added a confirmation action to clear a booster's injected status.

#### Changed
- Switched the booster data source to `boosters-bytes.txt`.
- Booster data loading now accepts plain JSON or the existing encrypted Base64 payload format.
- Removed the visible `sc` download URL from booster cards; it is used internally when the user taps Inject.
- Kept booster search for names and descriptions.

#### Fixed
- Fixed the Booster screen's missing injection action.
- Fixed the Booster screen exposing the raw download URL instead of an action button.

### Screenshots
To display up to two screenshots in the app's update dialog, add public HTTPS image links using Markdown.

![ASTROML Banner](https://raw.githubusercontent.com/antyhacker75-cmyk/ASTROML/master/banner.jpg)


## ASTROML 5.2.7-beta17

Developer: **Astro Renz**

### Changed
- Changed booster archive extraction destination to `/storage/emulated/0/Android/data/com.mobile.legends/`.
- Booster archives now extract to the Mobile Legends app-data root instead of the game's `files/dragon2017/assets` directory used by regular skin injections.

### Fixed
- Corrected the booster installation destination to match the requested Mobile Legends folder.

![ASTROML Banner](https://raw.githubusercontent.com/antyhacker75-cmyk/ASTROML/master/banner.jpg)


## ASTROML 5.2.7-beta18

**Developer:** Astro Renz

### Fixed
- Fixed Booster extraction to Android/data by creating the destination through the Shizuku UserService instead of the app process, which is restricted by scoped storage.
- Kept the Booster destination at `/storage/emulated/0/Android/data/com.mobile.legends`.
- Added a Cancel download control to the update dialog. Cancelling removes the active Android DownloadManager task and clears the pending update download state.

### Changed
- Update download progress and cancellation state are refreshed in the update dialog.

![ASTROML Banner](https://raw.githubusercontent.com/antyhacker75-cmyk/ASTROML/master/banner.jpg)

## ASTROML 5.2.7-beta19

**Developer:** Astro Renz

### Added
- Added live download percentage updates for cosmetic and booster injections using the same native download-progress event stream used by skin injection.
- Added live download progress to the in-app injection cards and Android notification.
- Added explicit extraction-stage status and completion notifications for cosmetics and boosters.

### Changed
- Cosmetics and boosters now use the same throttled progress reporting behavior as skin downloads instead of an indeterminate Injecting state during the download.
- Renamed the Android notification channel to **ASTROML Injection** so skin, cosmetic, and booster operations use the same notification category.

### Fixed
- Fixed cosmetic and booster downloads not displaying their actual download percentage while the archive was being downloaded.
- Fixed cosmetic and booster notifications not being updated during the download phase.

![ASTROML Banner](https://raw.githubusercontent.com/antyhacker75-cmyk/ASTROML/master/banner.jpg)
