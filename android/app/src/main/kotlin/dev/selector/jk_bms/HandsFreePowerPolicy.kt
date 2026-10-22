package dev.selector.jk_bms

/** CPU leases follow actual GPS work, independently of the service's location type. */
internal class HandsFreePowerPolicy {
    private var location = false
    private var signalled = false
    private var active = false
    private var bootstrapUntil = 0L

    fun claimLocation(value: Boolean, nowMillis: Long) {
        if (!value) {
            clear()
        } else if (!location) {
            location = true
            signalled = false
            active = false
            bootstrapUntil = nowMillis + BOOTSTRAP_MILLIS
        }
    }

    fun signal(value: Boolean) {
        if (!location) return
        signalled = true
        active = value
    }

    fun leaseMillis(nowMillis: Long): Long {
        if (!location) return 0
        if (signalled) return if (active) ACTIVE_MILLIS else 0
        return (bootstrapUntil - nowMillis).coerceIn(0, BOOTSTRAP_MILLIS)
    }

    fun clear() {
        location = false
        signalled = false
        active = false
        bootstrapUntil = 0
    }

    companion object {
        const val BOOTSTRAP_MILLIS = 45_000L
        const val ACTIVE_MILLIS = 60_000L
    }
}
