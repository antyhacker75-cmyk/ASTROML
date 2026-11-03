# ASTROML Android release signing

Every APK published for `com.astroml.dev` must be signed with the **same Android signing keystore** as the currently installed ASTROML app. Android does not allow an in-place update when the signing certificate changes. CPU architecture (ARM32/ARM64/Universal) does not override this signature rule.

## Required GitHub Actions secrets

- `ANDROID_KEYSTORE_B64`: Base64-encoded original release keystore file.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: key alias.
- `ANDROID_KEY_PASSWORD`: key password.

The release workflow now fails instead of silently producing a debug-signed APK if these secrets are missing. Keep a secure offline backup of the keystore; losing it means future APKs cannot update installs signed with it. Never commit the keystore or passwords.

## If the app already reports a signature conflict

The new release must use the exact signing key that signed the installed app. If the currently installed app was previously distributed from a workflow that used an ephemeral GitHub Actions debug key, there is no way to convert that installation to a different signing key in place. Back up any app data you need, uninstall that old build, install the first APK signed with the permanent release keystore, and use that same keystore for every future release. Uninstalling removes local app data.

Install only one matching APK build per device (ARM32, ARM64, or Universal). These are alternative packages for the same application ID, not separate apps.
