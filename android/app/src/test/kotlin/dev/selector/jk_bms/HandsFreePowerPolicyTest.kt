package dev.selector.jk_bms

import org.junit.Assert.*
import org.junit.Test

class HandsFreePowerPolicyTest {
    @Test fun `location type alone provides only one bounded bootstrap`() {
        val policy = HandsFreePowerPolicy()
        policy.claimLocation(true, 1_000)
        assertEquals(45_000L, policy.leaseMillis(1_000))
        assertEquals(15_000L, policy.leaseMillis(31_000))
        policy.claimLocation(true, 31_000)
        assertEquals(0L, policy.leaseMillis(46_000))
        assertEquals(0L, policy.leaseMillis(86_401_000))
    }

    @Test fun `explicit idle releases bootstrap immediately without removing location type`() {
        val policy = HandsFreePowerPolicy()
        policy.claimLocation(true, 0)
        policy.signal(false)
        assertEquals(0L, policy.leaseMillis(100))
        policy.claimLocation(true, 200)
        assertEquals(0L, policy.leaseMillis(200))
        policy.signal(true)
        assertEquals(60_000L, policy.leaseMillis(300))
    }

    @Test fun `active GPS renews a bounded lease and stop releases it`() {
        val policy = HandsFreePowerPolicy()
        policy.claimLocation(true, 0)
        policy.signal(true)
        assertEquals(60_000L, policy.leaseMillis(1_000))
        assertEquals(60_000L, policy.leaseMillis(100_000))
        policy.signal(false)
        assertEquals(0L, policy.leaseMillis(100_001))
    }

    @Test fun `release clears a previous active GPS claim`() {
        val policy = HandsFreePowerPolicy()
        policy.claimLocation(true, 0)
        policy.signal(true)
        policy.clear()
        policy.signal(true)
        assertEquals(0L, policy.leaseMillis(1_000))
        policy.claimLocation(false, 2_000)
        assertEquals(0L, policy.leaseMillis(2_000))
        policy.claimLocation(true, 3_000)
        assertEquals(45_000L, policy.leaseMillis(3_000))
    }
}
