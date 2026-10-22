package dev.selector.jk_bms

import android.companion.AssociationInfo
import android.companion.CompanionDeviceService
import android.companion.DevicePresenceEvent
import android.os.Build

/** Android creates this service for an associated nearby battery, with no UI. */
class HandsFreeCompanionService : CompanionDeviceService() {
    override fun onCreate() {
        super.onCreate()
        HandsFreeRuntime.initialize(this)
    }
    @Deprecated("Android 12 compatibility")
    override fun onDeviceAppeared(address: String) {
        if (Build.VERSION.SDK_INT < 33) HandsFreeRuntime.onPresence(address = address, ble = true)
    }
    @Deprecated("Android 12 compatibility")
    override fun onDeviceDisappeared(address: String) {
        if (Build.VERSION.SDK_INT < 33) HandsFreeRuntime.onPresence(address = address, ble = false)
    }
    @Deprecated("Android 13 to 15 compatibility")
    override fun onDeviceAppeared(associationInfo: AssociationInfo) {
        if (Build.VERSION.SDK_INT in 33..35) HandsFreeRuntime.onPresence(
            associationId = associationInfo.id, ble = true)
    }
    @Deprecated("Android 13 to 15 compatibility")
    override fun onDeviceDisappeared(associationInfo: AssociationInfo) {
        if (Build.VERSION.SDK_INT in 33..35) HandsFreeRuntime.onPresence(
            associationId = associationInfo.id, ble = false)
    }
    override fun onDevicePresenceEvent(event: DevicePresenceEvent) {
        if (Build.VERSION.SDK_INT < 36) return
        when (event.event) {
            DevicePresenceEvent.EVENT_BLE_APPEARED -> HandsFreeRuntime.onPresence(
                associationId = event.associationId, ble = true)
            DevicePresenceEvent.EVENT_BLE_DISAPPEARED -> HandsFreeRuntime.onPresence(
                associationId = event.associationId, ble = false)
            DevicePresenceEvent.EVENT_BT_CONNECTED -> HandsFreeRuntime.onPresence(
                associationId = event.associationId, bluetooth = true)
            DevicePresenceEvent.EVENT_BT_DISCONNECTED -> HandsFreeRuntime.onPresence(
                associationId = event.associationId, bluetooth = false)
            // Newer releases add association-removal events. Reconcile the
            // association list without requiring symbols newer than compile 36.
            else -> HandsFreeRuntime.refresh()
        }
    }
}
