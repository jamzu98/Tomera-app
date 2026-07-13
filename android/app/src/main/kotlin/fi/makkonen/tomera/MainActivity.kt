package fi.makkonen.tomera

import android.app.Activity
import android.content.Intent
import android.system.Os
import android.system.OsConstants
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

private const val BACKUP_CHANNEL = "fi.makkonen.tomera/portable_backup"
private const val PICK_BACKUP_REQUEST = 7041
private const val MAX_BACKUP_BYTES = 128L * 1024L * 1024L

class MainActivity : FlutterActivity() {
    private var pendingBackupPicker: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "databasePath" -> result.success(databaseFile().absolutePath)
                    "pickBackupFile" -> pickBackupFile(result)
                    "replaceDatabase" -> {
                        val stagedPath = call.argument<String>("stagedPath")
                        if (stagedPath.isNullOrBlank()) {
                            result.error("invalid_argument", "Missing stagedPath", null)
                            return@setMethodCallHandler
                        }
                        try {
                            replaceDatabase(File(stagedPath))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("replace_failed", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun databaseFile(): File =
        File(File(applicationContext.dataDir, "app_flutter"), "tomera.sqlite")

    private fun pickBackupFile(result: MethodChannel.Result) {
        if (pendingBackupPicker != null) {
            result.error("picker_busy", "A backup picker is already open", null)
            return
        }
        pendingBackupPicker = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        startActivityForResult(intent, PICK_BACKUP_REQUEST)
    }

    @Deprecated("Deprecated in Android, retained for FlutterActivity result delivery")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_BACKUP_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingBackupPicker
        pendingBackupPicker = null
        if (result == null) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        var destination: File? = null
        try {
            val destinationFile =
                File.createTempFile("tomera_import_", ".tomera-backup", cacheDir)
            destination = destinationFile
            contentResolver.openInputStream(uri).use { input ->
                requireNotNull(input) { "The selected file could not be opened" }
                destinationFile.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var copied = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        copied += count
                        require(copied <= MAX_BACKUP_BYTES) {
                            "The selected backup is too large"
                        }
                        output.write(buffer, 0, count)
                    }
                    output.flush()
                }
            }
            result.success(destinationFile.absolutePath)
        } catch (error: Exception) {
            destination?.delete()
            result.error("read_failed", error.message, null)
        }
    }

    private fun replaceDatabase(staged: File) {
        require(staged.isFile) { "The staged database does not exist" }
        val live = databaseFile()
        live.parentFile?.mkdirs()
        val installing = File(live.parentFile, "${live.name}.installing")
        staged.inputStream().use { input ->
            installing.outputStream().use { output ->
                input.copyTo(output)
                output.flush()
                output.fd.sync()
            }
        }

        // Drift has already closed and checkpointed the live connection. Any
        // remaining sidecars belong to the old database and must not be paired
        // with the restored main file.
        File("${live.absolutePath}-wal").delete()
        File("${live.absolutePath}-shm").delete()
        File("${live.absolutePath}-journal").delete()

        try {
            // POSIX rename replaces the target atomically on the same volume.
            Os.rename(installing.absolutePath, live.absolutePath)
            val directoryFd = Os.open(
                live.parentFile!!.absolutePath,
                OsConstants.O_RDONLY,
                0,
            )
            try {
                Os.fsync(directoryFd)
            } finally {
                Os.close(directoryFd)
            }
        } finally {
            installing.delete()
        }
    }

    override fun onDestroy() {
        pendingBackupPicker?.error(
            "activity_destroyed",
            "The backup picker was closed",
            null,
        )
        pendingBackupPicker = null
        super.onDestroy()
    }
}
