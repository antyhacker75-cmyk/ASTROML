
package com.astroml.dev

import android.Manifest
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

import android.os.Bundle
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import java.net.URL
import java.util.concurrent.ConcurrentHashMap

import com.astroml.dev.shizuku.ShizukuManager
import com.astroml.dev.engine.GameTarget
import com.astroml.dev.engine.AstroMlEngine

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

import java.io.File
import android.content.Intent
import android.net.Uri
import android.app.DownloadManager
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {

    private val scope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var resumeEventSink: EventChannel.EventSink? = null
    private var downloadProgressSink: EventChannel.EventSink? = null
    private data class InjectionNotificationState(
        val title: String,
        val message: String,
        val progress: Int,
        val imageUrl: String,
        val ongoing: Boolean
    )
    private val notificationStates = ConcurrentHashMap<Int, InjectionNotificationState>()
    private val notificationImages = ConcurrentHashMap<String, Bitmap>()
    private val notificationImagesLoading = ConcurrentHashMap.newKeySet<String>()
    @Volatile private var autoDismissNotifications = true
    @Volatile private var notificationDismissSeconds = 30

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.astroml.dev/lifecycle"
        ).setStreamHandler(object : EventChannel.StreamHandler {

            override fun onListen(
                arguments: Any?,
                events: EventChannel.EventSink?
            ) {
                resumeEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                resumeEventSink = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.astroml.dev/download_progress"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                downloadProgressSink = events
            }
            override fun onCancel(arguments: Any?) {
                downloadProgressSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.astroml.dev/updater"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppInfo" -> result.success(mapOf(
                    "versionName" to (packageManager.getPackageInfo(packageName, 0).versionName ?: "0.0.0"),
                    "versionCode" to if (Build.VERSION.SDK_INT >= 28) packageManager.getPackageInfo(packageName, 0).longVersionCode else packageManager.getPackageInfo(packageName, 0).versionCode.toLong(),
                    "abis" to Build.SUPPORTED_ABIS.toList()
                ))
                "getDeviceInfo" -> result.success(mapOf(
                    "androidVersion" to Build.VERSION.RELEASE,
                    "manufacturer" to Build.MANUFACTURER,
                    "model" to Build.MODEL,
                    "marketName" to Build.MODEL,
                    "device" to Build.DEVICE,
                    "chipset" to if (Build.VERSION.SDK_INT >= 31) Build.SOC_MODEL else Build.HARDWARE
                ))
                "showUpdateNotification" -> {
                    val version = call.argument<String>("version") ?: "new version"
                    val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                    val channelId = "astroml_updates"
                    if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(channelId, "ASTROML updates", NotificationManager.IMPORTANCE_DEFAULT))
                    val notification = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
                    notification.setSmallIcon(android.R.drawable.stat_sys_download_done).setContentTitle("ASTROML update available").setContentText("Version $version is available. Open ASTROML to download.").setAutoCancel(true)
                    manager.notify(5105, notification.build())
                    result.success(true)
                }
                "enqueueUpdateDownload" -> {
                    val url = call.argument<String>("url") ?: ""
                    val name = call.argument<String>("name") ?: "ASTROML-update.apk"
                    if (url.isBlank()) { result.error("ARGS", "Download URL is missing", null) } else {
                        try {
                            val request = DownloadManager.Request(Uri.parse(url))
                                .setTitle("ASTROML update")
                                .setDescription(name)
                                .setMimeType("application/vnd.android.package-archive")
                                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                                .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, name)
                                .setAllowedOverMetered(true).setAllowedOverRoaming(true)
                            val id = (getSystemService(DOWNLOAD_SERVICE) as DownloadManager).enqueue(request)
                            result.success(id)
                        } catch (e: Exception) { result.error("DOWNLOAD", e.message, null) }
                    }
                }
                "getUpdateDownload" -> {
                    val id = call.argument<Number>("id")?.toLong() ?: -1L
                    val manager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
                    val cursor = manager.query(DownloadManager.Query().setFilterById(id))
                    if (cursor != null && cursor.moveToFirst()) {
                        val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                        val downloaded = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                        val total = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                        // Android 10+ restricts COLUMN_LOCAL_FILENAME. Use DownloadManager's
                        // content URI and pass it directly to the package installer.
                        cursor.close()
                        val downloadedUri = if (status == DownloadManager.STATUS_SUCCESSFUL) {
                            manager.getUriForDownloadedFile(id)?.toString()
                        } else null
                        result.success(mapOf(
                            "status" to status,
                            "downloaded" to downloaded,
                            "total" to total,
                            "uri" to downloadedUri
                        ))
                    } else { cursor?.close(); result.success(null) }
                }
                "canInstallPackages" -> result.success(Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls())
                "requestInstallPermission" -> {
                    if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "installApk" -> {
                    val value = call.argument<String>("path") ?: ""
                    if (value.isBlank()) {
                        result.error("APK_MISSING", "Downloaded APK URI was not provided.", null)
                    } else if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                        result.error("INSTALL_PERMISSION", "Allow ASTROML to install updates, then tap Install again.", null)
                    } else {
                        try {
                            val uri = if (value.startsWith("content://")) {
                                Uri.parse(value)
                            } else {
                                val apk = File(if (value.startsWith("file://")) Uri.parse(value).path ?: "" else value)
                                if (!apk.exists() || !apk.isFile) throw IllegalStateException("Downloaded APK was not found.")
                                FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
                            }
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        AstroMlEngine.init(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.astroml.dev/engine"
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "startBackgroundWork" -> {
                    val intent = android.content.Intent(this, InjectionKeepAliveService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                    result.success(true)
                }

                "stopBackgroundWork" -> {
                    stopService(android.content.Intent(this, InjectionKeepAliveService::class.java))
                    result.success(true)
                }

                "setNotificationSettings" -> {
                    autoDismissNotifications = call.argument<Boolean>("autoDismiss") ?: true
                    notificationDismissSeconds = (call.argument<Int>("seconds") ?: 30).coerceIn(5, 300)
                    result.success(true)
                }

                "updateInjectionNotification" -> {
                    val title = call.argument<String>("title") ?: "ASTROML injection"
                    val message = call.argument<String>("message") ?: "Working..."
                    val progress = call.argument<Int>("progress") ?: 0
                    val image = call.argument<String>("image") ?: ""
                    val ongoing = call.argument<Boolean>("ongoing") ?: true
                    val notificationId = call.argument<Int>("notificationId") ?: (title.hashCode() and 0x7fffffff)
                    showInjectionNotification(title, message, progress, image, ongoing, notificationId)
                    result.success(true)
                }

                "findGame" -> scope.launch {
                    runCatching { AstroMlEngine.findGame() }
                        .onSuccess { result.success(gameToMap(it)) }
                        .onFailure {
                            result.error("ENGINE", it.message, null)
                        }
                }

                "storageGranted" -> {
                    result.success(AstroMlEngine.storageGranted())
                }

                "openStorageSettings" -> {
                    AstroMlEngine.openStorageSettings()
                    result.success(true)
                }

                "shizukuState" -> {
                    ShizukuManager.checkState()
                    result.success(shizukuStateName())
                }

                "requestShizukuPermission" -> {
                    ShizukuManager.requestPermission()
                    result.success(true)
                }

                "bindShizuku" -> {
                    ShizukuManager.bind()
                    result.success(true)
                }

                "downloadFile" -> scope.launch {
                    val url = call.argument<String>("url") ?: ""
                    val path = call.argument<String>("path") ?: ""

                    if (url.isBlank() || path.isBlank()) {
                        result.error(
                            "ARGS",
                            "url and path are required",
                            null
                        )
                        return@launch
                    }

                    runCatching {
                        var lastProgressAt = 0L
                        var lastProgressPercent = -1
                        AstroMlEngine.downloadFile(url, File(path)) { downloaded, total ->
                            if (total > 0L) {
                                val percent = ((downloaded * 100L) / total).toInt().coerceIn(0, 100)
                                val now = android.os.SystemClock.elapsedRealtime()
                                // Publish at most 4 updates/second and only when the
                                // visible percentage changes. Never throttle file IO.
                                if (percent != lastProgressPercent &&
                                    (now - lastProgressAt >= 250L || percent == 100)) {
                                    lastProgressAt = now
                                    lastProgressPercent = percent
                                    runOnUiThread {
                                        downloadProgressSink?.success(mapOf(
                                            "downloaded" to downloaded,
                                            "total" to total,
                                            "progress" to percent
                                        ))
                                    }
                                }
                            }
                        }
                    }
                        .onSuccess { result.success(it) }
                        .onFailure {
                            result.error("DOWNLOAD", it.message, null)
                        }
                }

                "unzip" -> scope.launch {
                    val source = call.argument<String>("source") ?: ""
                    val target = call.argument<String>("target") ?: ""

                    if (source.isBlank() || target.isBlank()) {
                        result.error(
                            "ARGS",
                            "source and target are required",
                            null
                        )
                        return@launch
                    }

                    runCatching {
                        AstroMlEngine.unzip(File(source), File(target))
                    }
                        .onSuccess { result.success(true) }
                        .onFailure {
                            result.error("UNZIP", it.message, null)
                        }
                }

                "deleteFolder" -> scope.launch {
                    val path = call.argument<String>("path") ?: ""

                    if (path.isBlank()) {
                        result.error("ARGS", "path is required", null)
                        return@launch
                    }

                    runCatching {
                        AstroMlEngine.deleteFolder(File(path))
                    }
                        .onSuccess { result.success(true) }
                        .onFailure {
                            result.error("DELETE", it.message, null)
                        }
                }

                "sha256Files" -> scope.launch {
                    val paths =
                        call.argument<List<String>>("paths") ?: emptyList()

                    runCatching {
                        AstroMlEngine.sha256Files(paths.map(::File))
                    }
                        .onSuccess { result.success(it) }
                        .onFailure {
                            result.error("SHA256", it.message, null)
                        }
                }

                "hashZipEntries" -> scope.launch {
                    val path = call.argument<String>("path") ?: ""

                    runCatching {
                        AstroMlEngine.hashZipEntries(File(path))
                            .map { listOf(it.first, it.second) }
                    }
                        .onSuccess { result.success(it) }
                        .onFailure {
                            result.error("ZIPHASH", it.message, null)
                        }
                }

                "clearRepairMarkers" -> scope.launch {
                    val assetsDir =
                        call.argument<String>("assetsDir") ?: ""
                    val dataDir =
                        call.argument<String>("dataDir") ?: ""

                    if (assetsDir.isBlank() || dataDir.isBlank()) {
                        result.error(
                            "ARGS",
                            "assetsDir and dataDir are required",
                            null
                        )
                        return@launch
                    }

                    runCatching {
                        AstroMlEngine.clearRepairMarkers(
                            GameTarget(
                                packageName = "",
                                assetsDir = File(assetsDir),
                                dataDir = File(dataDir)
                            )
                        )
                    }
                        .onSuccess { result.success(true) }
                        .onFailure {
                            result.error("MARKERS", it.message, null)
                        }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun showInjectionNotification(title: String, message: String, progress: Int, imageUrl: String, ongoing: Boolean, notificationId: Int) {
        val state = InjectionNotificationState(title, message, progress, imageUrl, ongoing)
        notificationStates[notificationId] = state
        renderInjectionNotification(notificationId, state)

        // Fetch the artwork once per URL, off the main thread. Progress updates reuse
        // the cached bitmap and never trigger another image request.
        if (imageUrl.isNotBlank() && !notificationImages.containsKey(imageUrl) && notificationImagesLoading.add(imageUrl)) {
            scope.launch(Dispatchers.IO) {
                val bitmap = runCatching {
                    val connection = URL(imageUrl).openConnection().apply {
                        connectTimeout = 7000
                        readTimeout = 7000
                        useCaches = true
                    }
                    connection.getInputStream().use { input ->
                        val bytes = input.readBytes()
                        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                        val maxSide = maxOf(bounds.outWidth, bounds.outHeight)
                        val sample = if (maxSide > 1600) (maxSide / 1600).coerceAtLeast(1) else 1
                        val options = BitmapFactory.Options().apply { inSampleSize = sample.coerceAtMost(4); inPreferredConfig = Bitmap.Config.ARGB_8888 }
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                    }
                }.getOrNull()
                notificationImagesLoading.remove(imageUrl)
                if (bitmap != null) notificationImages[imageUrl] = bitmap
                withContext(Dispatchers.Main) {
                    notificationStates[notificationId]?.let { latest ->
                        if (latest.imageUrl == imageUrl) renderInjectionNotification(notificationId, latest)
                    }
                }
            }
        }

        if (!ongoing && autoDismissNotifications) {
            scope.launch {
                kotlinx.coroutines.delay(notificationDismissSeconds * 1000L)
                val current = notificationStates[notificationId]
                if (current != null && !current.ongoing) {
                    val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                    manager.cancel(notificationId)
                    notificationStates.remove(notificationId)
                }
            }
        }
    }

    private fun renderInjectionNotification(notificationId: Int, state: InjectionNotificationState) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "astroml_injection"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(channelId, "Skin injection", NotificationManager.IMPORTANCE_LOW))
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, channelId) else Notification.Builder(this)
        builder.setSmallIcon(applicationInfo.icon)
            .setContentTitle(state.title)
            .setContentText(state.message)
            .setOnlyAlertOnce(true)
            .setOngoing(state.ongoing)
            .setProgress(if (state.progress < 0) 0 else 100, state.progress.coerceIn(0, 100), state.progress < 0 && state.ongoing)
        notificationImages[state.imageUrl]?.let { bitmap ->
            // Keep the high-resolution cached bitmap for expanded artwork;
            // Android scales the large icon for the compact notification itself.
            builder.setLargeIcon(bitmap)
            builder.setStyle(Notification.BigPictureStyle().bigPicture(bitmap).bigLargeIcon(bitmap))
        }
        if (!state.ongoing) builder.setProgress(0, 0, false)
        manager.notify(notificationId, builder.build())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        ShizukuManager.init(applicationContext)
        // Start a bounded auto-bind retry as soon as the APK process launches.
        ShizukuManager.onAppForeground()

        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4108)
        }

        // Do not open All Files Access automatically on first launch.
        // The app presents its own permission/onboarding screen and opens
        // Android settings only after the user taps the permission action.

        if (
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                ),
                1001
            )
        }
    }

    override fun onResume() {
        super.onResume()

        // Re-check Shizuku whenever the app returns from the permission screen.
        // If permission was just granted, ShizukuManager.checkState() starts
        // binding the UserService automatically; no second button tap needed.
        ShizukuManager.checkState()
        ShizukuManager.onAppForeground()
        resumeEventSink?.success("resume")
    }

    // Runs after the Activity has completed its resume transition. This is
    // useful when Shizuku's binder becomes available just after the splash.
    override fun onPostResume() {
        super.onPostResume()
        ShizukuManager.onAppForeground()
    }

    override fun onPause() {
        ShizukuManager.onAppBackground()
        super.onPause()
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun shizukuStateName(): String =
        when (ShizukuManager.state) {
            ShizukuManager.State.Bound -> "bound"
            ShizukuManager.State.Idle -> "idle"
            ShizukuManager.State.NoPermission -> "no_permission"
            ShizukuManager.State.Unavailable -> "unavailable"
        }

    private fun gameToMap(
        game: GameTarget?
    ): Map<String, String>? =
        game?.let {
            mapOf(
                "packageName" to it.packageName,
                "assetsDir" to it.assetsDir.absolutePath,
                "dataDir" to it.dataDir.absolutePath
            )
        }
}
