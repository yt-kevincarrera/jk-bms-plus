package dev.selector.jk_bms

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanFilter
import android.companion.AssociationInfo
import android.companion.AssociationRequest
import android.companion.BluetoothLeDeviceFilter
import android.companion.CompanionDeviceManager
import android.companion.ObservingDevicePresenceRequest
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.lang.ref.WeakReference
import java.util.Locale

/** One process-wide Flutter engine. A companion event never launches an Activity. */
internal object HandsFreeRuntime {
    const val CHANNEL = "dev.selector.jk_bms/hands_free"
    const val ASSOCIATION_REQUEST = 5511
    const val PERMISSIONS_REQUEST = 5512
    private const val PREFS = "jk_bms_hands_free"
    private lateinit var context: Context
    private val main = Handler(Looper.getMainLooper())
    private val policy = HandsFreePolicy()
    private val powerPolicy = HandsFreePowerPolicy()
    private var loaded = false
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var activity = WeakReference<MainActivity>(null)
    private var lastReason: String? = null
    private var pendingPermissions: MethodChannel.Result? = null
    private var permissionUsesLocation = true
    private var pendingAssociation: Setup? = null
    private var title = "JK BMS +"
    private var text = "Conectando con la batería"
    private var claimSequence = 0L
    private var appliedClaimSequence = -1L
    private var claimConfirmed = false
    var locationClaim = false
        private set

    private data class Setup(
        val token: Long,
        val deviceId: String,
        val deviceName: String,
        val usesLocation: Boolean,
        val result: MethodChannel.Result,
    )

    private val prefs get() = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val manager get() = context.getSystemService(CompanionDeviceManager::class.java)
    private val supported get() = Build.VERSION.SDK_INT >= 31 &&
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_COMPANION_DEVICE_SETUP)
    private val deviceId get() = prefs.getString("device_id", null)
    private val deviceName get() = prefs.getString("device_name", null)
    private val usesLocation get() = prefs.getBoolean("uses_location", true)

    fun initialize(appContext: Context) {
        if (loaded) return
        context = appContext.applicationContext
        policy.enabled = prefs.getBoolean("enabled", false)
        // Ownership belongs to the live Dart isolate, never the previous process.
        // A stale persisted claim would otherwise start an orphaned host at boot.
        policy.dartClaim = false
        prefs.edit().remove("dart_claim").apply()
        // A cold restart starts connectedDevice only. Dart reclaims location after recovery.
        locationClaim = false
        title = prefs.getString("notification_title", null) ?: title
        text = prefs.getString("notification_text", null) ?: text
        loaded = true
    }

    fun getOrCreateEngine(appContext: Context): FlutterEngine {
        check(Looper.myLooper() == Looper.getMainLooper())
        initialize(appContext)
        engine?.let { return it }
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context)
        loader.ensureInitializationComplete(context, null)
        val created = FlutterEngine(context)
        engine = created
        channel = MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL).also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> result.success(status())
                        "enable" -> enable(
                            call.argument<String>("deviceId"),
                            call.argument<String>("deviceName") ?: "",
                            call.argument<Boolean>("usesLocation") ?: true,
                            result,
                        )
                        "disable" -> { disable(); result.success(status()) }
                        "forget" -> { forget(); result.success(status()) }
                        "refresh" -> { refresh(); result.success(status()) }
                        "requestPrerequisites" -> requestPrerequisites(
                            call.argument<Boolean>("usesLocation") ?: true, result,
                        )
                        "openAppSettings" -> {
                            val host = requireActivity()
                            host.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:${context.packageName}")))
                            result.success(true)
                        }
                        "notificationStart" -> {
                            val accepted = claimNotification(
                                call.argument<String>("title") ?: "JK BMS +",
                                call.argument<String>("text") ?: "",
                                call.argument<Boolean>("usesLocation") ?: true,
                            )
                            if (accepted) awaitHost(result, claimSequence) else result.success(false)
                        }
                        "notificationUpdate" -> {
                            title = call.argument<String>("title") ?: title
                            text = call.argument<String>("text") ?: text
                            HandsFreeHostService.instance?.updateNotification()
                            result.success(null)
                        }
                        "notificationPower" -> {
                            if (policy.dartClaim && locationClaim) {
                                powerPolicy.signal(call.argument<Boolean>("active") ?: false)
                            } else powerPolicy.clear()
                            HandsFreeHostService.instance?.updatePowerLease()
                            result.success(null)
                        }
                        "notificationStop" -> {
                            claimSequence++
                            claimConfirmed = false
                            policy.dartClaim = false
                            locationClaim = false
                            powerPolicy.clear()
                            reconcileHost()
                            result.success(null)
                        }
                        "notificationRunning" -> result.success(HandsFreeHostService.running)
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("hands_free_failed", error.message, null)
                }
            }
        }
        registerInstaller(created)
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return created
    }

    fun attachActivity(host: MainActivity) { activity = WeakReference(host) }

    fun detachActivity(host: MainActivity) {
        if (activity.get() !== host) return
        activity.clear()
        pendingPermissions?.success(status("activity_required"))
        pendingPermissions = null
        cancelSetup("association_cancelled")
    }

    private fun requireActivity(): MainActivity = activity.get()?.takeUnless { it.isFinishing }
        ?: throw IllegalStateException("An open Activity is required for this action")

    private fun hasPermission(permission: String) =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    private fun prerequisiteReason(location: Boolean): String? {
        if (!supported) return "unsupported_android"
        if (!hasPermission(Manifest.permission.BLUETOOTH_SCAN) ||
            !hasPermission(Manifest.permission.BLUETOOTH_CONNECT)) return "bluetooth_permission"
        if ((Build.VERSION.SDK_INT >= 33 && !hasPermission(Manifest.permission.POST_NOTIFICATIONS)) ||
            !context.getSystemService(android.app.NotificationManager::class.java).areNotificationsEnabled()) {
            return "notification_permission"
        }
        if (location && !hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
            return "precise_location_permission"
        }
        if (location && !hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)) {
            return "background_location_permission"
        }
        if (location && !context.getSystemService(LocationManager::class.java).isLocationEnabled) {
            return "location_service_disabled"
        }
        return null
    }

    private fun bluetoothOn(): Boolean = try {
        context.getSystemService(BluetoothManager::class.java).adapter?.isEnabled == true
    } catch (_: SecurityException) { false }

    private fun associationFor(address: String): AssociationInfo? {
        if (Build.VERSION.SDK_INT < 33 || !supported) return null
        return try {
            val savedId = if (deviceId == address) prefs.getInt("association_id", -1) else -1
            val associations = manager.myAssociations
            associations.firstOrNull { it.id == savedId } ?: associations.firstOrNull {
                it.deviceMacAddress?.toString()?.equals(address, ignoreCase = true) == true
            }
        } catch (_: Exception) { null }
    }

    @Suppress("DEPRECATION")
    private fun isAssociated(address: String?): Boolean {
        if (!supported || address == null) return false
        return try {
            if (Build.VERSION.SDK_INT >= 33) associationFor(address) != null
            else manager.associations.any { it.equals(address, ignoreCase = true) }
        } catch (_: Exception) { false }
    }

    fun status(reason: String? = null): Map<String, Any?> {
        policy.associated = isAssociated(deviceId)
        val stateReason = reason ?: when {
            !supported -> "unsupported_android"
            !policy.enabled -> lastReason ?: "disabled"
            prerequisiteReason(usesLocation) != null -> prerequisiteReason(usesLocation)
            !policy.associated -> "association_required"
            !bluetoothOn() -> "bluetooth_off"
            lastReason != null -> lastReason
            HandsFreeHostService.running -> "running"
            policy.present -> "present"
            else -> "waiting_for_device"
        }
        return mapOf(
            "supported" to supported,
            "enabled" to policy.enabled,
            "deviceId" to deviceId,
            "deviceName" to deviceName,
            "associated" to policy.associated,
            "present" to policy.present,
            "running" to HandsFreeHostService.running,
            "reason" to stateReason,
        )
    }

    private fun emit(presence: Boolean = false) {
        channel?.invokeMethod(if (presence) "presenceChanged" else "stateChanged", status())
    }

    private fun requestPrerequisites(location: Boolean, result: MethodChannel.Result) {
        if (!supported) { result.success(status("unsupported_android")); return }
        if (pendingPermissions != null) {
            result.error("permission_request_in_progress", "A permission request is already open", null)
            return
        }
        val permissions = mutableListOf(Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT)
        if (location) {
            permissions += Manifest.permission.ACCESS_FINE_LOCATION
            permissions += Manifest.permission.ACCESS_COARSE_LOCATION
        }
        if (Build.VERSION.SDK_INT >= 33) permissions += Manifest.permission.POST_NOTIFICATIONS
        val missing = permissions.filterNot { hasPermission(it) }.toMutableList()
        // Android 12 may ignore a FINE-only upgrade after COARSE was granted.
        // Both location permissions must be requested together on that path too.
        if (location && !hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) &&
            Manifest.permission.ACCESS_COARSE_LOCATION !in missing) {
            missing += Manifest.permission.ACCESS_COARSE_LOCATION
        }
        if (missing.isEmpty()) {
            lastReason = prerequisiteReason(location)
            result.success(status(lastReason))
            return
        }
        permissionUsesLocation = location
        pendingPermissions = result
        try {
            requireActivity().requestPermissions(missing.toTypedArray(), PERMISSIONS_REQUEST)
        } catch (error: Exception) {
            pendingPermissions = null
            result.error("activity_required", error.message, null)
        }
    }

    fun permissionsResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSIONS_REQUEST) return false
        val result = pendingPermissions ?: return true
        pendingPermissions = null
        lastReason = prerequisiteReason(permissionUsesLocation)
        result.success(status(lastReason))
        emit()
        return true
    }

    private fun enable(address: String?, name: String, location: Boolean, result: MethodChannel.Result) {
        if (!supported) { result.success(status("unsupported_android")); return }
        val target = address?.trim()?.uppercase(Locale.ROOT)
        if (target == null || !BluetoothAdapter.checkBluetoothAddress(target)) {
            result.error("invalid_device", "Select a Bluetooth LE battery first", null)
            return
        }
        val blocked = prerequisiteReason(location)
        if (blocked != null) { lastReason = blocked; result.success(status(blocked)); return }
        if (!bluetoothOn()) { result.success(status("bluetooth_off")); return }
        if (!context.getSystemService(LocationManager::class.java).isLocationEnabled) {
            result.success(status("location_service_disabled")); return
        }
        cancelSetup("association_cancelled")
        val setup = Setup(policy.beginSetup(), target, name, location, result)
        pendingAssociation = setup
        if (isAssociated(target)) { finishSetup(setup); return }
        try { requireActivity() } catch (error: Exception) {
            failSetup(setup, "activity_required"); return
        }
        val filter = BluetoothLeDeviceFilter.Builder()
            .setScanFilter(ScanFilter.Builder().setDeviceAddress(target).build()).build()
        val request = AssociationRequest.Builder().addDeviceFilter(filter).setSingleDevice(true).build()
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                manager.associate(request, context.mainExecutor,
                    object : CompanionDeviceManager.Callback() {
                        override fun onAssociationPending(sender: IntentSender) = launchChooser(setup, sender)
                        override fun onAssociationCreated(info: AssociationInfo) {
                            if (!isCurrent(setup)) {
                                // Consent may finish after disable or Activity teardown.
                                if (!policy.enabled || deviceId != setup.deviceId) {
                                    try { manager.disassociate(info.id) } catch (_: Exception) { }
                                }
                                return
                            }
                            finishSetup(setup)
                        }
                        override fun onFailure(error: CharSequence?) = failSetup(setup, "association_failed")
                    })
            } else {
                @Suppress("DEPRECATION")
                manager.associate(request, object : CompanionDeviceManager.Callback() {
                    @Deprecated("Android 12 compatibility")
                    override fun onDeviceFound(sender: IntentSender) = launchChooser(setup, sender)
                    override fun onFailure(error: CharSequence?) = failSetup(setup, "association_failed")
                }, main)
            }
        } catch (_: Exception) { failSetup(setup, "association_failed") }
    }

    private fun isCurrent(setup: Setup) = pendingAssociation === setup && policy.acceptsSetup(setup.token)

    private fun launchChooser(setup: Setup, sender: IntentSender) {
        if (!isCurrent(setup)) return
        try {
            requireActivity().startIntentSenderForResult(sender, ASSOCIATION_REQUEST, null, 0, 0, 0)
        } catch (_: Exception) { failSetup(setup, "association_failed") }
    }

    fun associationResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != ASSOCIATION_REQUEST) return false
        val setup = pendingAssociation ?: return true
        if (resultCode != Activity.RESULT_OK) { failSetup(setup, "association_cancelled"); return true }
        if (Build.VERSION.SDK_INT < 33) finishSetup(setup)
        return true
    }

    private fun finishSetup(setup: Setup) {
        if (!isCurrent(setup)) return
        if (!isAssociated(setup.deviceId)) { failSetup(setup, "association_failed"); return }
        val blocked = prerequisiteReason(setup.usesLocation)
        if (blocked != null) { failSetup(setup, blocked); return }
        // Re-enabling an existing association does not need another scan or
        // drop current presence. A replacement gets no claim from the old pack.
        if (deviceId != setup.deviceId) {
            stopObservation()
            policy.presence(ble = false, bluetooth = false)
            policy.dartClaim = false
            claimSequence++
            claimConfirmed = false
            locationClaim = false
            powerPolicy.clear()
            context.stopService(Intent(context, HandsFreeHostService::class.java))
        }
        policy.enabled = true
        policy.associated = true
        val associationId = if (Build.VERSION.SDK_INT >= 33) associationFor(setup.deviceId)?.id ?: -1 else -1
        prefs.edit().putBoolean("enabled", true).putString("device_id", setup.deviceId)
            .putString("device_name", setup.deviceName).putBoolean("uses_location", setup.usesLocation)
            .putInt("association_id", associationId).commit()
        pendingAssociation = null
        lastReason = null
        registerObservation()
        setup.result.success(status())
        emit()
    }

    private fun failSetup(setup: Setup, reason: String) {
        if (!isCurrent(setup)) return
        pendingAssociation = null
        lastReason = reason
        setup.result.success(status(reason))
        emit()
    }

    private fun cancelSetup(reason: String) {
        val setup = pendingAssociation ?: return
        pendingAssociation = null
        policy.beginSetup()
        setup.result.success(status(reason))
    }

    fun disable() {
        cancelSetup("association_cancelled")
        stopObservation()
        // Keep an existing ride's foreground service until Dart has started
        // its manual backend, then explicitly releases this claim. Turning
        // automatic discovery off must not remove GPS access mid-handover.
        val keepLiveClaim = policy.dartClaim && claimConfirmed && HandsFreeHostService.running
        policy.disable(preserveClaim = keepLiveClaim)
        if (!keepLiveClaim) {
            claimSequence++
            claimConfirmed = false
            locationClaim = false
            powerPolicy.clear()
        }
        lastReason = null
        prefs.edit().putBoolean("enabled", false).remove("dart_claim").commit()
        if (!keepLiveClaim) context.stopService(Intent(context, HandsFreeHostService::class.java))
        emit()
    }

    @Suppress("DEPRECATION")
    private fun forget() {
        val target = deviceId
        disable()
        if (target != null && supported) {
            try {
                if (Build.VERSION.SDK_INT >= 33) associationFor(target)?.let { manager.disassociate(it.id) }
                else if (isAssociated(target)) manager.disassociate(target)
            } catch (_: Exception) { /* An already removed association is forgotten too. */ }
        }
        prefs.edit().remove("device_id").remove("device_name").remove("uses_location")
            .remove("association_id").commit()
        policy.associated = false
        emit()
    }

    @Suppress("DEPRECATION")
    private fun registerObservation() {
        if (!policy.enabled || !supported) return
        val target = deviceId ?: return
        policy.associated = isAssociated(target)
        if (!policy.associated) { lastReason = "association_required"; return }
        try {
            if (Build.VERSION.SDK_INT >= 36) {
                val association = associationFor(target) ?: return
                manager.startObservingDevicePresence(ObservingDevicePresenceRequest.Builder()
                    .setAssociationId(association.id).build())
            } else manager.startObservingDevicePresence(target)
        } catch (_: SecurityException) { lastReason = "bluetooth_permission" }
        catch (_: Exception) { lastReason = "association_failed" }
    }

    @Suppress("DEPRECATION")
    private fun stopObservation() {
        if (!supported) return
        val target = deviceId ?: return
        try {
            if (Build.VERSION.SDK_INT >= 36) {
                val association = associationFor(target) ?: return
                manager.stopObservingDevicePresence(ObservingDevicePresenceRequest.Builder()
                    .setAssociationId(association.id).build())
            } else if (isAssociated(target)) manager.stopObservingDevicePresence(target)
        } catch (_: Exception) { /* Revoked associations have nothing left to unregister. */ }
    }

    fun refresh() {
        lastReason = null
        registerObservation()
        if (!bluetoothOn() || !isAssociated(deviceId)) policy.presence(ble = false, bluetooth = false)
        reconcileHost()
        emit()
    }

    fun onPresence(address: String? = null, associationId: Int? = null,
        ble: Boolean? = null, bluetooth: Boolean? = null) {
        if (!policy.enabled) return
        val target = deviceId ?: return
        if (address == null && associationId == null) return
        if (address != null && !target.equals(address, ignoreCase = true)) return
        if (associationId != null && associationFor(target)?.id != associationId) return
        policy.presence(ble, bluetooth)
        lastReason = null
        reconcileHost()
        emit(presence = true)
    }

    private fun claimNotification(newTitle: String, newText: String, location: Boolean): Boolean {
        policy.associated = isAssociated(deviceId)
        if (!policy.enabled || !policy.associated) return false
        val blocked = prerequisiteReason(location)
        if (blocked != null) { lastReason = blocked; emit(); return false }
        title = newTitle
        text = newText
        claimSequence++
        policy.dartClaim = true
        locationClaim = location
        powerPolicy.claimLocation(location, SystemClock.elapsedRealtime())
        saveNotification()
        reconcileHost()
        if (lastReason == "start_failed") {
            releaseUnconfirmedClaim()
            return false
        }
        return true
    }

    private fun awaitHost(result: MethodChannel.Result, request: Long, attempts: Int = 50) {
        when {
            request != claimSequence -> result.success(false)
            !policy.enabled || !policy.dartClaim || lastReason == "start_failed" || attempts <= 0 -> {
                releaseUnconfirmedClaim()
                result.success(false)
            }
            HandsFreeHostService.running && appliedClaimSequence == request -> {
                claimConfirmed = true
                result.success(true)
            }
            else -> main.postDelayed({ awaitHost(result, request, attempts - 1) }, 100)
        }
    }

    private fun releaseUnconfirmedClaim() {
        if (claimConfirmed && HandsFreeHostService.running) return
        policy.dartClaim = false
        locationClaim = false
        powerPolicy.clear()
        reconcileHost()
    }

    private fun saveNotification() {
        prefs.edit().putString("notification_title", title).putString("notification_text", text).apply()
    }

    fun notificationTitle() = title
    fun notificationText() = text
    fun powerLeaseMillis() = powerPolicy.leaseMillis(SystemClock.elapsedRealtime())

    fun shouldRunHost(): Boolean {
        policy.associated = isAssociated(deviceId)
        return policy.shouldRun && prerequisiteReason(usesLocation || locationClaim) == null &&
            (bluetoothOn() || policy.dartClaim)
    }

    private fun reconcileHost() {
        if (!shouldRunHost()) {
            context.stopService(Intent(context, HandsFreeHostService::class.java))
            return
        }
        try {
            // A disabled companion may retain only its live Dart claim while
            // handing a ride to the manual backend. Do not stop that backend.
            if (!policy.enabled && HandsFreeHostService.running) {
                HandsFreeHostService.instance?.updateNotification()
                return
            }
            // Always send a start request: a previous disable may have queued
            // stopService while its old instance is still visible in this process.
            ContextCompat.startForegroundService(context, Intent(context, HandsFreeHostService::class.java))
        } catch (_: Exception) {
            lastReason = "start_failed"
        }
    }

    fun hostStarted() {
        appliedClaimSequence = claimSequence
        lastReason = null
        getOrCreateEngine(context)
        emit()
    }

    fun hostFailed() { claimConfirmed = false; lastReason = "start_failed"; emit() }
    fun hostStopped() { claimConfirmed = false; emit() }

    private fun registerInstaller(created: FlutterEngine) {
        MethodChannel(created.dartExecutor.binaryMessenger, "dev.selector.jk_bms/installer")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                        "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 ||
                            context.packageManager.canRequestPackageInstalls())
                        "openInstallSettings" -> {
                            if (Build.VERSION.SDK_INT >= 26) requireActivity().startActivity(Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${context.packageName}")))
                            result.success(null)
                        }
                        "installApk" -> {
                            val path = call.argument<String>("path")
                            if (path == null) { result.error("no_path", "No package path given", null); return@setMethodCallHandler }
                            val file = File(path)
                            check(file.exists()) { "Package not found" }
                            val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", file)
                            requireActivity().startActivity(Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            })
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("install_failed", error.message, null) }
            }
    }
}
