package dev.selector.jk_bms

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands a downloaded update to the system installer.
 *
 * This app is not on any store, so an update is a package the rider installs
 * themselves. All this does is show them the system's own install prompt --
 * nothing here installs anything silently, and nothing can: Android requires
 * the user to confirm, every time.
 */
class MainActivity : FlutterActivity() {
    private val channel = "dev.selector.jk_bms/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())

                    // Android 8+ gates installing packages behind a per-app
                    // permission the user grants in Settings. Asking first
                    // avoids handing over an APK that silently goes nowhere.
                    "canInstall" -> result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                    )

                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        }
                        result.success(null)
                    }

                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("no_path", "No package path given", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(File(path))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun installApk(file: File) {
        if (!file.exists()) throw IllegalStateException("Package not found: ${file.path}")

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.updates",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
