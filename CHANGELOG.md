# ASTROML Changelog

## Upcoming update system improvements
- Moved automatic update checking to an app-level manager so it runs after startup without opening Settings.
- Routed foreground, background, and terminated-state Firebase notification interactions to the same custom update dialog.
- Changed release notification copy to “Version X is ready. Tap to update.”
- Added a startup check fallback and a throttled check when the app returns to the foreground.
- Prevented duplicate update dialogs from overlapping notification and automatic-check events.
