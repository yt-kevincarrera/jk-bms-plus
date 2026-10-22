package dev.selector.jk_bms

import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Reconcile saved consent after boot/update/radio changes; no Activity is launched. */
class HandsFreeRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                BluetoothAdapter.ACTION_STATE_CHANGED)) return
        HandsFreeRuntime.initialize(context)
        HandsFreeRuntime.refresh()
    }
}

class HandsFreePauseReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        HandsFreeRuntime.initialize(context)
        HandsFreeRuntime.disable()
    }
}
