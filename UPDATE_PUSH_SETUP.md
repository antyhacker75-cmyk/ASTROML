# ASTROML push update integration

This source adds Firebase Cloud Messaging topic subscription (`astroml_updates`) controlled by the existing auto-check switch. The release workflow sends a push notification after publishing a release when the `FIREBASE_SERVICE_ACCOUNT` repository secret is configured.

## Required repository secret

`FIREBASE_SERVICE_ACCOUNT` must contain the full JSON of a newly generated Firebase Admin SDK service-account key for project `r3nz-409a1`. Do not commit this credential or include it in the APK. Any previously exposed key must be revoked.

## Behavior and limitations

- Auto-check ON subscribes the app to `astroml_updates`; OFF unsubscribes and reveals the manual GitHub check button.
- A release push opens ASTROML and fetches the latest GitHub release to show its notes and up to two Markdown-linked screenshots in a dialog.
- Android/FCM displays the notification while the app is backgrounded or closed, subject to network, notification permission, and Android power-management restrictions. Force-stopping the app can prevent delivery until it is launched again.
- The current APK download screen remains in the updater widget. This integration does not claim that its Dart-stream download continues after the app process is killed; that requires wiring the existing native DownloadManager methods to the UI and installer flow.

## Firebase Android setup

`android/app/google-services.json` is configured for package `com.astroml.dev`. Gradle applies Google Services plugin 4.4.2; Flutter dependencies use firebase_core and firebase_messaging.
