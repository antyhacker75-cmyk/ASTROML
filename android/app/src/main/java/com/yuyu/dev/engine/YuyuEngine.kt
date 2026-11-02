package com.yuyu.dev.engine
import com.yuyu.dev.shizuku.IUnzipService

import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.Process
import android.provider.Settings

import com.yuyu.dev.shizuku.ShizukuManager
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import org.apache.commons.compress.archivers.sevenz.SevenZFile
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.OkHttpClient
import okhttp3.Request

data class GameTarget(
    val packageName: String,
    val assetsDir: File,
    val dataDir: File
)

sealed interface ExtractionStrategy {
    suspend fun unzip(source: File, target: File)
    suspend fun deleteFolder(path: File)
    suspend fun sha256Files(paths: List<File>): List<String?>
}

private object ArchiveFormat {
    fun detect(file: File): String? = runCatching {
        FileInputStream(file).use { input ->
            val sig = ByteArray(6)
            val n = input.read(sig)
            if (n >= 4 && sig[0] == 0x50.toByte() && sig[1] == 0x4B.toByte() &&
                ((sig[2] == 0x03.toByte() && sig[3] == 0x04.toByte()) ||
                 (sig[2] == 0x05.toByte() && sig[3] == 0x06.toByte()) ||
                 (sig[2] == 0x07.toByte() && sig[3] == 0x08.toByte()))) return@use "zip"
            if (n == 6 && sig.contentEquals(byteArrayOf(
                    0x37, 0x7A, 0xBC.toByte(), 0xAF.toByte(), 0x27, 0x1C
                ))) return@use "7z"
            null
        }
    }.getOrNull()
}

class DirectStrategy : ExtractionStrategy {
    override suspend fun unzip(source: File, target: File) = withContext(Dispatchers.IO) {
        require(source.isFile && source.length() > 0L) { "Archive is missing or empty" }
        if (!target.exists() && !target.mkdirs()) error("Cannot create extraction directory")
        when (ArchiveFormat.detect(source)) {
            "zip" -> extractZip(source, target)
            "7z" -> extractSevenZip(source, target)
            else -> throw IllegalArgumentException("Unsupported or invalid ZIP/7z archive")
        }
    }

    private fun safeOutput(target: File, name: String): File {
        val normalized = name.replace('\\', '/')
        if (normalized.isBlank() || normalized.startsWith("/") ||
            normalized.startsWith("//") || Regex("^[A-Za-z]:").containsMatchIn(normalized) ||
            normalized.split("/").any { it == ".." }) {
            throw SecurityException("Illegal archive entry: $name")
        }
        val root = target.canonicalPath
        val output = File(target, normalized).canonicalFile
        if (output.path != root && !output.path.startsWith(root + File.separator)) {
            throw SecurityException("Archive entry attempts path traversal: $name")
        }
        return output
    }

    private fun extractZip(source: File, target: File) {
        var entries = 0
        var total = 0L
        ZipInputStream(FileInputStream(source)).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                if (++entries > 10_000) throw SecurityException("Too many archive entries")
                val out = safeOutput(target, entry.name)
                if (entry.isDirectory) {
                    if (!out.exists() && !out.mkdirs()) error("Cannot create directory: ${entry.name}")
                } else {
                    out.parentFile?.let { if (!it.exists() && !it.mkdirs()) error("Cannot create parent directory") }
                    FileOutputStream(out).use { output ->
                        val buffer = ByteArray(8192)
                        while (true) {
                            val n = zis.read(buffer)
                            if (n <= 0) break
                            total += n
                            if (total > 512L * 1024 * 1024) throw SecurityException("Archive exceeds 512 MiB expanded limit")
                            output.write(buffer, 0, n)
                        }
                    }
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
    }

    private fun extractSevenZip(source: File, target: File) {
        var entries = 0
        var total = 0L
        SevenZFile.builder().setFile(source).get().use { sevenZ ->
            val buffer = ByteArray(8192)
            var entry = sevenZ.nextEntry
            while (entry != null) {
                if (++entries > 10_000) throw SecurityException("Too many archive entries")
                val name = entry.name ?: throw IllegalArgumentException("Unnamed 7z entry")
                val out = safeOutput(target, name)
                if (entry.isDirectory) {
                    if (!out.exists() && !out.mkdirs()) error("Cannot create directory: $name")
                } else {
                    out.parentFile?.let { if (!it.exists() && !it.mkdirs()) error("Cannot create parent directory") }
                    FileOutputStream(out).use { output ->
                        while (true) {
                            val n = sevenZ.read(buffer)
                            if (n <= 0) break
                            total += n
                            if (total > 512L * 1024 * 1024) throw SecurityException("Archive exceeds 512 MiB expanded limit")
                            output.write(buffer, 0, n)
                        }
                    }
                }
                entry = sevenZ.nextEntry
            }
        }
    }

    override suspend fun deleteFolder(path: File) {
        withContext(Dispatchers.IO) { path.deleteRecursively() }
    }

    override suspend fun sha256Files(paths: List<File>): List<String?> = withContext(Dispatchers.IO) {
        val digest = MessageDigest.getInstance("SHA-256")
        paths.map { path -> runCatching {
            if (!path.isFile) return@runCatching null
            digest.reset()
            FileInputStream(path).use { input ->
                val buffer = ByteArray(8192)
                while (true) { val n = input.read(buffer); if (n <= 0) break; digest.update(buffer, 0, n) }
            }
            digest.digest().joinToString("") { "%02x".format(it) }
        }.getOrNull() }
    }
}
class ShizukuStrategy(
    private val awaitService: suspend () -> IUnzipService
) : ExtractionStrategy {

    override suspend fun unzip(source: File, target: File) {
        val service = awaitService()
        val done = CompletableDeferred<Result<Unit>>()
        val callback = object : com.yuyu.dev.shizuku.IUnzipCallback.Stub() {
            override fun onProgress(progress: Int, currentFile: String?) {}
            override fun onComplete() { done.complete(Result.success(Unit)) }
            override fun onError(message: String?) {
                done.complete(Result.failure(IllegalStateException(message ?: "unzip failed")))
            }
        }
        service.unzip(source.absolutePath, target.absolutePath, callback)
        val result = withTimeoutOrNull(300_000L) {
            done.await()
        } ?: throw IllegalStateException("Shizuku unzip timed out")
        result.getOrThrow()
    }

    override suspend fun deleteFolder(path: File) {
        withTimeoutOrNull(60_000L) {
            awaitService().deleteFolder(path.absolutePath)
        } ?: throw IllegalStateException("Shizuku delete timed out")
    }

    override suspend fun sha256Files(paths: List<File>): List<String?> {
        return withTimeoutOrNull(120_000L) {
            val service = awaitService()
            val result = service.sha256Files(paths.map { it.absolutePath }.toTypedArray())
            result?.toList() ?: List(paths.size) { null }
        } ?: throw IllegalStateException("Shizuku sha256 timed out")
    }
}

object YuyuEngine {

    private val supportedPackages = listOf(
        "com.mobile.legends", "com.vng.mlbbvn", "com.mobilelegends.hwag",
        "com.mobilelegends.mi", "com.hhgame.mlbbvn", "com.mobile.legends.usa",
        "com.mobile.legends.lite", "com.mobile.legends.beta", "com.moonton.mlbb.cn",
        "com.mobile.Legends.am", "com.mobile.legends.ft", "com.mobile.legends.bil",
        "com.mobiin.gp"
    )

    @Volatile
    private var appContext: Context? = null

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .build()

    fun init(context: Context) {
        appContext = context.applicationContext
        ShizukuManager.init(context)
    }

    private fun strategy(): ExtractionStrategy =
        if (ShizukuManager.service != null) {
            ShizukuStrategy { ShizukuManager.awaitService() }
        } else {
            DirectStrategy()
        }

    fun findGame(): GameTarget? {
        val ctx = appContext ?: return null
        val pm = ctx.packageManager
        for (pkg in supportedPackages) {
            val info = runCatching { pm.getApplicationInfo(pkg, 0) }.getOrNull() ?: continue
            val assets = File("/storage/emulated/0/Android/data/$pkg/files/dragon2017/assets")
            val data = File(info.dataDir, "files/dragon2017/assets")
            return GameTarget(pkg, assets, data)
        }
        return null
    }

    suspend fun downloadFile(url: String, dest: File): Boolean = withContext(Dispatchers.IO) {
        if (dest.exists() && dest.length() > 0 && ArchiveFormat.detect(dest) != null) {
            return@withContext true
        }
        runCatching {
            val request = Request.Builder().url(url).build()
            client.newCall(request).execute().use { response ->
                check(response.isSuccessful) { "HTTP ${response.code}" }

                val body = response.body
                    ?: throw IllegalStateException("Response body is null")

                val contentLength = body.contentLength()
                if (contentLength > 0 && contentLength > 200L * 1024 * 1024) {
                    throw IllegalStateException("File too large")
                }
                dest.parentFile?.mkdirs()
                val tmpFile = File(dest.parent, "${dest.name}.tmp")

                try {
                    FileOutputStream(tmpFile).use { output ->
                        body.byteStream().use { input ->
                            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                            var total: Long = 0
                            var read = input.read(buffer)
                            while (read > 0) {
                                total += read
                                if (total > 200L * 1024 * 1024) {
                                    throw IllegalStateException("File too large")
                                }
                                output.write(buffer, 0, read)
                                read = input.read(buffer)
                            }
                        }
                    }
                    if (contentLength > 0 && tmpFile.length() != contentLength) {
                        tmpFile.delete()
                        throw IllegalStateException(
                            "Incomplete download: expected $contentLength bytes, got ${tmpFile.length()}"
                        )
                    }
                    if (tmpFile.length() == 0L) {
                        tmpFile.delete()
                        throw IllegalStateException("Downloaded file is empty")
                    }
                    if (ArchiveFormat.detect(tmpFile) == null) {
                        tmpFile.delete()
                        throw IllegalStateException("Downloaded file is not a valid ZIP or 7z archive")
                    }
                    if (dest.exists()) dest.delete()
                    tmpFile.renameTo(dest)
                } catch (e: Exception) {
                    tmpFile.delete()
                    throw e
                }
            }
        }.isSuccess
    }

    suspend fun unzip(source: File, target: File) =
        strategy().unzip(source, target)

    suspend fun deleteFolder(path: File) =
        strategy().deleteFolder(path)

    suspend fun sha256Files(paths: List<File>): List<String?> =
        strategy().sha256Files(paths)

    fun hashZipEntries(zip: File): List<Pair<String, String>> {
        if (!zip.isFile) return emptyList()
        val digest = MessageDigest.getInstance("SHA-256")
        val result = mutableListOf<Pair<String, String>>()
        return runCatching {
            when (ArchiveFormat.detect(zip)) {
                "zip" -> ZipInputStream(FileInputStream(zip)).use { zis ->
                    var count = 0
                    var entry = zis.nextEntry
                    while (entry != null && ++count <= 10_000) {
                        val name = entry.name.replace('\\', '/')
                        if (!entry.isDirectory && !name.startsWith("/") && !name.split("/").contains("..")) {
                            digest.reset()
                            val buffer = ByteArray(8192)
                            while (true) { val n = zis.read(buffer); if (n <= 0) break; digest.update(buffer, 0, n) }
                            result.add(name to digest.digest().joinToString("") { "%02x".format(it) })
                        }
                        zis.closeEntry(); entry = zis.nextEntry
                    }
                }
                "7z" -> SevenZFile.builder().setFile(zip).get().use { sevenZ ->
                    var count = 0
                    val buffer = ByteArray(8192)
                    var entry = sevenZ.nextEntry
                    while (entry != null && ++count <= 10_000) {
                        val name = entry.name ?: ""
                        if (!entry.isDirectory && !name.startsWith("/") && !name.replace('\\', '/').split("/").contains("..")) {
                            digest.reset()
                            while (true) { val n = sevenZ.read(buffer); if (n <= 0) break; digest.update(buffer, 0, n) }
                            result.add(name to digest.digest().joinToString("") { "%02x".format(it) })
                        }
                        entry = sevenZ.nextEntry
                    }
                }
                else -> return emptyList()
            }
            result
        }.getOrDefault(emptyList())
    }

    suspend fun clearRepairMarkers(game: GameTarget) {
        val configDir = game.dataDir.parentFile ?: game.dataDir
        listOf(
            File(game.assetsDir.parentFile ?: game.dataDir, "config.ini"),
            File(configDir, "dragon2017/config.ini"),
            File(game.dataDir, "config.ini")
        ).forEach { marker ->
            if (marker.exists()) runCatching { strategy().deleteFolder(marker) }
        }
    }

    fun storageGranted(): Boolean {
        val ctx = appContext ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ctx.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        }
    }

    fun openStorageSettings() {
        val ctx = appContext ?: return

        val directIntent = android.content.Intent(
            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION
        )
            .setData(android.net.Uri.parse("package:${ctx.packageName}"))
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)

        val listIntent = android.content.Intent(
            Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION
        ).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)

        val appInfoIntent = android.content.Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS
        )
            .setData(android.net.Uri.parse("package:${ctx.packageName}"))
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)

        val pm = ctx.packageManager
        when {
            directIntent.resolveActivity(pm) != null ->
                runCatching { ctx.startActivity(directIntent) }
                    .onFailure { runCatching { ctx.startActivity(listIntent) }
                        .onFailure { ctx.startActivity(appInfoIntent) } }
            listIntent.resolveActivity(pm) != null ->
                runCatching { ctx.startActivity(listIntent) }
                    .onFailure { ctx.startActivity(appInfoIntent) }
            else ->
                runCatching { ctx.startActivity(appInfoIntent) }
        }
    }
}
