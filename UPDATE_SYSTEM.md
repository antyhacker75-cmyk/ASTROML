# ASTROML release and in-app updater

## Publishing a release

Create and push a version tag. The tag includes `v`, while the GitHub Release title is just the numeric version:

```bash
git tag v5.1.6
git push origin v5.1.6
```

The `ASTROML Build & Release` workflow builds ARM32, ARM64 and universal APKs, then attaches them to a GitHub Release titled `5.1.6`.

## Update notes and screenshots

After the workflow publishes the release, edit its description and add your release notes. The ASTROML updater reads the release description. It displays up to two screenshots when the description contains Markdown image links with public HTTPS image URLs:

```markdown
![Update screenshot 1](https://your-host.example/image-1.png)
![Update screenshot 2](https://your-host.example/image-2.png)
```

The updater chooses the ARM64 or ARM32 APK based on the device ABI, falling back to the universal APK. It downloads the APK into ASTROML's private app storage and then offers an Install button.

## Android installation behavior

Android does not permit an ordinary app to silently install an APK update. On first use, the user must allow ASTROML to install unknown apps in Android settings. After download, tapping **Install update** opens Android's package installer, where the user confirms installation. The update must be signed with the same signing key as the installed app and use a higher version code. Keep the release keystore secrets consistent in GitHub Actions.

## Repository configuration

The updater currently checks `antyhacker75-cmyk/yuyu` using GitHub's public Releases API. If the repository is renamed or transferred, update `_owner` and `_repo` in `lib/widgets/update_checker.dart`.
