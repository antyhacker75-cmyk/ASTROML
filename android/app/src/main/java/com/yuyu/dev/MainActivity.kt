
package com.yuyu.dev

import android.Manifest
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.Settings
import android.os.Bundle

import com.yuyu.dev.shizuku.ShizukuManager
import com.yuyu.dev.engine.GameTarget
import com.yuyu.dev.engine.YuyuEngine

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

import java.io.File

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {

    private val scope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var resumeEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.yuyu.dev/lifecycle"
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

        YuyuEngine.init(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.yuyu.dev/engine"
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "findGame" -> scope.launch {
                    runCatching { YuyuEngine.findGame() }
                        .onSuccess { result.success(gameToMap(it)) }
                        .onFailure {
                            result.error("ENGINE", it.message, null)
                        }
                }

                "storageGranted" -> {
                    result.success(YuyuEngine.storageGranted())
                }

                "openStorageSettings" -> {
                    YuyuEngine.openStorageSettings()
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
                        YuyuEngine.downloadFile(url, File(path))
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
                        YuyuEngine.unzip(File(source), File(target))
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
                        YuyuEngine.deleteFolder(File(path))
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
                        YuyuEngine.sha256Files(paths.map(::File))
                    }
                        .onSuccess { result.success(it) }
                        .onFailure {
                            result.error("SHA256", it.message, null)
                        }
                }

                "hashZipEntries" -> scope.launch {
                    val path = call.argument<String>("path") ?: ""

                    runCatching {
                        YuyuEngine.hashZipEntries(File(path))
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
                        YuyuEngine.clearRepairMarkers(
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        ShizukuManager.init(applicationContext)

        if (android.os.Build.VERSION.SDK_INT >=
            android.os.Build.VERSION_CODES.R
        ) {
            if (!Environment.isExternalStorageManager()) {
                try {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION
                    )
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION
                    )
                    startActivity(intent)
                }
            }
        }

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
        resumeEventSink?.success("resume")
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
