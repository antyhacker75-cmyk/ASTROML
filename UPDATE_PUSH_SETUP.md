# ASTROML push update integration

Firebase Cloud Messaging topic `astroml_updates` is controlled by the Automatically check for updates setting. The update manager is mounted at the app root, not inside Settings.

## Required repository secret

`FIREBASE_SERVICE_ACCOUNT` must contain the Firebase Admin SDK service-account JSON for the configured Firebase project. Keep it in GitHub Actions secrets; never commit it or include it in the APK.

## Behavior

- Auto-check ON subscribes to `astroml_updates`; OFF unsubscribes and leaves manual checking available in Settings.
- A published release sends `Version X is ready. Tap to update.`
- In the foreground, update push messages open the app's custom update dialog directly.
- From the background, tapping the FCM notification opens ASTROML and `onMessageOpenedApp` fetches the latest release and displays the same custom update/download/install dialog.
- From a terminated state, `getInitialMessage()` is consumed by the app-level manager after startup and displays that same dialog.
- A startup GitHub check is also performed as a fallback, and app resume checks are throttled to avoid excessive requests.
- Android notification permission, network availability, Firebase delivery, and device power management still affect push delivery. Android force-stop prevents FCM delivery until the user opens the app again.

## Firebase Android setup

`android/app/google-services.json` must match package `com.astroml.dev`. Flutter dependencies include `firebase_core` and `firebase_messaging`.
