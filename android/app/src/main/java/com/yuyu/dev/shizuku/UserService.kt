
package com.yuyu.dev.shizuku

import android.os.Process
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.zip.ZipInputStream
import org.apache.commons.compress.archivers.sevenz.SevenZFile

/**
 * Shizuku UserService.
 *
 * Supports ZIP and 7z archive extraction.
 */
class UserService : IUnzipService.Stub() {

    companion object {
        private const val TAG = "YuyuUserService"
        private const val BUFFER_SIZE = 8192
    }

    init {
        Log.i(TAG, "UserService process started")
    }

    override fun unzip(
        source: String,
        target: String,
        callback: IUnzipCallback?
    ) {
        Log.i(TAG, "Extraction requested: $source -> $target")

        val srcFile = File(source)
        val targetDir = File(target)

        if (!srcFile.isFile || srcFile.length() <= 0L) {
            callback?.onError("Source file not found or empty")
            return
        }

        if (!targetDir.exists() && !targetDir.mkdirs()) {
            callback?.onError("Cannot create target directory")
            return
        }

        if (!targetDir.isDirectory) {
            callback?.onError("Target is not a directory")
            return
        }

        try {
            val canonicalTarget = targetDir.canonicalFile

            when (detectArchiveFormat(srcFile)) {
                "zip" -> extractZip(srcFile, canonicalTarget, callback)
                "7z" -> extractSevenZip(srcFile, canonicalTarget, callback)
                else -> throw IllegalArgumentException(
                    "Unsupported or invalid ZIP/7z archive"
                )
            }

            Log.i(TAG, "Extraction completed")
            callback?.onProgress(100, "Completed")
            callback?.onComplete()

        } catch (e: Exception) {
            Log.e(TAG, "Extraction failed", e)

            callback?.onError(
                e.message ?: "Unknown extraction error"
            )
        }
    }

    private fun detectArchiveFormat(file: File): String? {
        return FileInputStream(file).use { input ->
            val sig = ByteArray(6)
            val count = input.read(sig)
            if (count >= 4 && sig[0] == 0x50.toByte() && sig[1] == 0x4B.toByte() &&
                ((sig[2] == 0x03.toByte() && sig[3] == 0x04.toByte()) ||
                 (sig[2] == 0x05.toByte() && sig[3] == 0x06.toByte()) ||
                 (sig[2] == 0x07.toByte() && sig[3] == 0x08.toByte()))) return@use "zip"
            if (count == 6 && sig.contentEquals(byteArrayOf(
                    0x37, 0x7A, 0xBC.toByte(), 0xAF.toByte(), 0x27, 0x1C
                ))) return@use "7z"
            null
        }
    }

    private fun extractZip(
        source: File,
        target: File,
        callback: IUnzipCallback?
    ) {
        Log.i(TAG, "ZIP extraction started")

        var processed = 0L
        val total = source.length()

        ZipInputStream(
            FileInputStream(source)
        ).use { zis ->

            var entry = zis.nextEntry

            while (entry != null) {

                val entryName = entry.name
                val outputFile = resolveSafePath(
                    target,
                    entryName
                )

                if (entry.isDirectory) {

                    if (!outputFile.exists() &&
                        !outputFile.mkdirs()
                    ) {
                        throw IllegalStateException(
                            "Cannot create directory: $entryName"
                        )
                    }

                } else {

                    outputFile.parentFile?.let { parent ->
                        if (!parent.exists() && !parent.mkdirs()) {
                            throw IllegalStateException(
                                "Cannot create parent directory: $entryName"
                            )
                        }
                    }

                    FileOutputStream(outputFile).use { output ->

                        val buffer = ByteArray(BUFFER_SIZE)

                        while (true) {
                            val read = zis.read(buffer)

                            if (read <= 0) break

                            output.write(buffer, 0, read)
                            processed += read

                            reportProgress(
                                processed,
                                total,
                                entryName,
                                callback
                            )
                        }
                    }
                }

                zis.closeEntry()
                entry = zis.nextEntry
            }
        }

        Log.i(TAG, "ZIP extraction finished")
    }

    private fun extractSevenZip(
        source: File,
        target: File,
        callback: IUnzipCallback?
    ) {
        Log.i(TAG, "7z extraction started")

        var processed = 0L

        SevenZFile.builder()
            .setFile(source)
            .get()
            .use { sevenZ ->

                val buffer = ByteArray(BUFFER_SIZE)

                var entry = sevenZ.nextEntry

                while (entry != null) {

                    val entryName = entry.name
                        ?: throw IllegalArgumentException(
                            "7z archive contains an unnamed entry"
                        )

                    val outputFile = resolveSafePath(
                        target,
                        entryName
                    )

                    if (entry.isDirectory) {

                        if (!outputFile.exists() &&
                            !outputFile.mkdirs()
                        ) {
                            throw IllegalStateException(
                                "Cannot create directory: $entryName"
                            )
                        }

                    } else {

                        outputFile.parentFile?.let { parent ->
                            if (!parent.exists() && !parent.mkdirs()) {
                                throw IllegalStateException(
                                    "Cannot create parent directory: $entryName"
                                )
                            }
                        }

                        FileOutputStream(outputFile).use { output ->

                            while (true) {
                                val read = sevenZ.read(buffer)

                                if (read <= 0) break

                                output.write(buffer, 0, read)
                                processed += read

                                reportProgress(
                                    processed,
                                    source.length(),
                                    entryName,
                                    callback
                                )
                            }
                        }
                    }

                    entry = sevenZ.nextEntry
                }
            }

        Log.i(TAG, "7z extraction finished")
    }

    /**
     * Prevents archive entries from escaping the target directory.
     */
    private fun resolveSafePath(
        target: File,
        entryName: String
    ): File {

        if (entryName.isBlank()) {
            throw SecurityException("Empty archive entry name")
        }

        val normalizedName = entryName.replace('\\', '/')

        if (
            normalizedName.startsWith("/") ||
            normalizedName.startsWith("//") ||
            Regex("^[A-Za-z]:").containsMatchIn(normalizedName) ||
            normalizedName.split("/").any { it == ".." }
        ) {
            throw SecurityException(
                "Illegal archive entry: $entryName"
            )
        }

        val outputFile = File(
            target,
            normalizedName
        ).canonicalFile

        val targetPath = target.canonicalPath
        val outputPath = outputFile.canonicalPath

        if (
            outputPath != targetPath &&
            !outputPath.startsWith(
                targetPath + File.separator
            )
        ) {
            throw SecurityException(
                "Archive entry attempts path traversal: $entryName"
            )
        }

        return outputFile
    }

    private fun reportProgress(
        processed: Long,
        total: Long,
        entryName: String,
        callback: IUnzipCallback?
    ) {
        // The archive's compressed size is only an estimate of
        // extraction progress, so reserve 100% for completion.
        val progress = if (total > 0L) {
            ((processed * 100L) / total)
                .toInt()
                .coerceIn(0, 99)
        } else {
            0
        }

        callback?.onProgress(
            progress,
            entryName
        )
    }

    override fun deleteFolder(path: String): Boolean {
        Log.i(TAG, "Delete requested: $path")

        return try {
            deleteRecursively(File(path))
        } catch (e: Exception) {
            Log.e(TAG, "Delete failed", e)
            false
        }
    }

    override fun sha256Files(
        paths: Array<out String>?
    ): Array<String?>? {

        Log.i(TAG, "SHA256 requested")

        if (paths == null) return null

        val digest = MessageDigest.getInstance("SHA-256")

        return paths.map { path ->

            try {
                val file = File(path)

                if (!file.isFile) {
                    return@map null
                }

                digest.reset()

                FileInputStream(file).use { input ->

                    val buffer = ByteArray(BUFFER_SIZE)

                    while (true) {
                        val read = input.read(buffer)

                        if (read <= 0) break

                        digest.update(buffer, 0, read)
                    }
                }

                digest.digest().joinToString("") {
                    "%02x".format(it)
                }

            } catch (e: Exception) {
                Log.e(TAG, "SHA256 failed for $path", e)
                null
            }

        }.toTypedArray()
    }

    override fun destroy() {
        Log.i(TAG, "Destroy requested")
        Process.killProcess(Process.myPid())
    }

    private fun deleteRecursively(file: File): Boolean {

        if (!file.exists()) {
            return true
        }

        if (file.isDirectory) {

            val children = file.listFiles() ?: return false

            for (child in children) {
                if (!deleteRecursively(child)) {
                    return false
                }
            }
        }

        return file.delete()
    }
}
