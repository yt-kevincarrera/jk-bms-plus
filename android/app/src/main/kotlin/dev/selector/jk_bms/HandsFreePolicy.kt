package dev.selector.jk_bms

/** Pure lifecycle policy. Physical presence and Dart's foreground claim are independent. */
internal class HandsFreePolicy {
    var generation: Long = 0
        private set
    var enabled: Boolean = false
    var associated: Boolean = false
    var blePresent: Boolean = false
        private set
    var bluetoothConnected: Boolean = false
        private set
    var dartClaim: Boolean = false

    val present: Boolean get() = blePresent || bluetoothConnected
    // A live Dart owner can finish a ride while automatic discovery is off.
    // This claim is process-local and is never restored from preferences.
    val shouldRun: Boolean get() = (enabled && associated && present) || dartClaim

    fun beginSetup(): Long = ++generation
    fun acceptsSetup(token: Long): Boolean = token == generation

    fun presence(ble: Boolean? = null, bluetooth: Boolean? = null) {
        ble?.let { blePresent = it }
        bluetooth?.let { bluetoothConnected = it }
    }

    fun disable(preserveClaim: Boolean = false) {
        generation++
        enabled = false
        if (!preserveClaim) dartClaim = false
        blePresent = false
        bluetoothConnected = false
    }
}
