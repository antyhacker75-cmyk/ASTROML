# ASTROML update notes

- Notification artwork is retained during download progress updates instead of being cleared; Android notifications use the skin artwork as a large icon and expanded big-picture image when the image is available.
- Injection requests are queued and processed sequentially. Users can tap Apply/Inject while another skin is running; new requests are added to the queue rather than starting concurrent writes to the game assets.
- Each queued skin receives its own notification, including its own artwork, download progress, extraction stage, and completion/failure state.
- Skin-to-Skin search results are shown in a dedicated result section and open the matching hero detail page, where the transformation target can be viewed and applied.
- Shizuku state is checked on Activity creation and every resume. If the permission remains granted but the UserService is no longer bound, `checkState()` requests a new bind; an already-live service is retained rather than unnecessarily torn down.

Build verification: ZIP integrity checked. Flutter and Android Gradle builds were not run in this environment.
