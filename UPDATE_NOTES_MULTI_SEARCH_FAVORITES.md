# ASTROML update: batch downloads, injected verification, favorites, search

- Inject All Favorites now pre-downloads up to three skin archives concurrently. Extraction/injection remains sequential to avoid multiple archives writing into the same game asset directory at the same time.
- Injected verification now compares the archive's expected SHA-256 with the actual extracted file, stores only verified files, awaits manifest persistence, and reports a result message after checking.
- Favorites use a larger framed image area with contain-fit rendering to reduce awkward cropping.
- Hero Discovery search now matches hero names, regular skin names, Other Skins names, and the global Newly Added feed.
- Skins whose name or image matches the Newly Added feed display a NEW badge.

Build note: Flutter/Dart SDK is not available in this environment, so a Flutter analyze/build was not run. ZIP integrity is checked separately.
