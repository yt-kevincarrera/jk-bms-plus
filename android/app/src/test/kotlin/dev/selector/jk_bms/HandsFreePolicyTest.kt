package dev.selector.jk_bms

import org.junit.Assert.*
import org.junit.Test

class HandsFreePolicyTest {
    private fun armed() = HandsFreePolicy().apply { enabled = true; associated = true }

    @Test fun `presence only works with consent and association`() {
        val policy = HandsFreePolicy()
        policy.presence(ble = true)
        assertFalse(policy.shouldRun)
        policy.enabled = true
        assertFalse(policy.shouldRun)
        policy.associated = true
        assertTrue(policy.shouldRun)
    }

    @Test fun `BLE and Bluetooth presence are independent`() {
        val policy = armed()
        policy.presence(ble = true, bluetooth = true)
        policy.presence(bluetooth = false)
        assertTrue(policy.present)
        assertTrue(policy.shouldRun)
        policy.presence(ble = false)
        assertFalse(policy.shouldRun)
        policy.presence(bluetooth = true)
        policy.presence(ble = false)
        assertTrue(policy.shouldRun)
    }

    @Test fun `active Dart trip survives loss of both physical signals`() {
        val policy = armed()
        policy.dartClaim = true
        policy.presence(ble = false, bluetooth = false)
        assertTrue(policy.shouldRun)
        policy.dartClaim = false
        assertFalse(policy.shouldRun)
    }

    @Test fun `release foreground claim retains a present companion`() {
        val policy = armed()
        policy.presence(ble = true)
        policy.dartClaim = true
        policy.dartClaim = false
        assertTrue(policy.shouldRun)
    }

    @Test fun `disable invalidates late consent and releases all ownership`() {
        val policy = armed()
        val consent = policy.beginSetup()
        policy.presence(ble = true, bluetooth = true)
        policy.dartClaim = true
        policy.disable()
        assertFalse(policy.acceptsSetup(consent))
        assertFalse(policy.enabled)
        assertFalse(policy.dartClaim)
        assertFalse(policy.present)
        assertFalse(policy.shouldRun)
        assertTrue(policy.associated) // Disable does not revoke a saved association.
    }

    @Test fun `a newer setup supersedes the previous consent callback`() {
        val policy = HandsFreePolicy()
        val old = policy.beginSetup()
        val current = policy.beginSetup()
        assertFalse(policy.acceptsSetup(old))
        assertTrue(policy.acceptsSetup(current))
    }

    @Test fun `a fresh process has no foreground claim even with saved consent`() {
        val previous = armed().apply { dartClaim = true }
        val restored = HandsFreePolicy().apply {
            enabled = previous.enabled
            associated = previous.associated
        }
        assertFalse(restored.dartClaim)
        assertFalse(restored.shouldRun)
        restored.presence(ble = true)
        assertTrue(restored.shouldRun)
    }

    @Test fun `disable preserves only a live claim until manual handover completes`() {
        val policy = armed().apply {
            presence(ble = true)
            dartClaim = true
        }
        policy.disable(preserveClaim = true)
        assertFalse(policy.enabled)
        assertFalse(policy.present)
        assertTrue(policy.dartClaim)
        assertTrue(policy.shouldRun)
        policy.dartClaim = false
        assertFalse(policy.shouldRun)
    }
}
