// Direct BLE link from the phone to an Even R1 ring (Conversate Plan B).
// Officially the R1 only pairs with G2; this talks to a ring the user already
// set up in the Even app (bonded at OS level), after that app releases it.
// Subscribe-only: Helix never writes to the ring.
package com.artjiang.helix.ring

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

enum class RingLinkState { OFF, CONNECTING, CONNECTED, NOT_FOUND, NO_PERMISSION }

@SuppressLint("MissingPermission") // Guarded by hasPermissions().
class R1Transport(
    context: Context,
    private val scope: CoroutineScope,
    clock: () -> Long = System::currentTimeMillis,
) {
    companion object {
        private const val TAG = "HelixR1"
        private fun uuid(short: String) = UUID.fromString("bae8$short-4f05-4503-8e65-3af1f7329d1f")
        val SERVICE: UUID = uuid("0001")
        val NOTIFY_CHARACTERISTICS: List<UUID> = listOf(uuid("0011"), uuid("0013"))
        val CLIENT_CHARACTERISTIC_CONFIG: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
        const val MAX_BACKOFF_MILLIS = 30_000L
    }

    private val appContext = context.applicationContext
    private val adapter: BluetoothAdapter?
        get() = (appContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private val stateFlow = MutableStateFlow(RingLinkState.OFF)
    val state: StateFlow<RingLinkState> = stateFlow.asStateFlow()
    private val nameFlow = MutableStateFlow<String?>(null)
    val deviceName: StateFlow<String?> = nameFlow.asStateFlow()
    private val lastGestureFlow = MutableStateFlow("")

    /** Last decoded gesture (or raw unknown frame) — for the phone UI / hardware checks. */
    val lastGesture: StateFlow<String> = lastGestureFlow.asStateFlow()

    /** Called on a binder thread; the caller hops to its own scope. */
    var onGesture: ((R1Gesture) -> Unit)? = null

    private val deduper = R1GestureDeduper(clock)
    private var running = false
    private var gatt: BluetoothGatt? = null
    private var device: BluetoothDevice? = null
    private var pendingSubscriptions = ArrayDeque<BluetoothGattCharacteristic>()
    private var backoffMillis = 1_000L
    private var reconnectJob: Job? = null

    fun hasPermissions(): Boolean {
        val needed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        return needed.all { ContextCompat.checkSelfPermission(appContext, it) == PackageManager.PERMISSION_GRANTED }
    }

    /** Finds the bonded ring and keeps the link up until [stop]. */
    fun start() {
        if (running) return
        running = true
        backoffMillis = 1_000L
        connectOrSearch()
    }

    fun stop() {
        running = false
        reconnectJob?.cancel()
        gatt?.let { runCatching { it.disconnect(); it.close() } }
        gatt = null
        stateFlow.value = RingLinkState.OFF
    }

    private fun connectOrSearch() {
        if (!running) return
        if (!hasPermissions()) {
            stateFlow.value = RingLinkState.NO_PERMISSION
            return
        }
        val bt = adapter?.takeIf { it.isEnabled } ?: run {
            stateFlow.value = RingLinkState.NOT_FOUND
            return
        }
        // Bonded devices only (see R1Frame.pickRing): never connect to a ring
        // just because something nearby advertises the right name.
        val bonded = runCatching { bt.bondedDevices.toList() }.getOrDefault(emptyList())
        val ring = bonded.firstOrNull { device ->
            R1Frame.pickRing(listOf(RingCandidate(runCatching { device.name }.getOrNull(), bonded = true))) != null
        }
        if (ring == null) {
            stateFlow.value = RingLinkState.NOT_FOUND
            return
        }
        connect(ring)
    }

    private fun connect(target: BluetoothDevice) {
        if (!running) return
        device = target
        nameFlow.value = runCatching { target.name }.getOrNull()
        stateFlow.value = RingLinkState.CONNECTING
        gatt?.let { runCatching { it.close() } }
        // autoConnect = true: a background connect that waits for the ring to
        // become reachable (woken, or released by the G2/Even app) instead of
        // a direct attempt that times out after ~10 s (GATT status 147) — the
        // ring sleeps between gestures, so direct attempts kept missing it.
        gatt = target.connectGatt(appContext, true, callback, BluetoothDevice.TRANSPORT_LE)
    }

    private fun scheduleReconnect() {
        if (!running) return
        reconnectJob?.cancel()
        val wait = backoffMillis
        backoffMillis = (backoffMillis * 2).coerceAtMost(MAX_BACKOFF_MILLIS)
        reconnectJob = scope.launch {
            delay(wait)
            connectOrSearch()
        }
    }

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> g.discoverServices()
                BluetoothProfile.STATE_DISCONNECTED -> {
                    runCatching { g.close() }
                    if (gatt === g) gatt = null
                    stateFlow.value = if (running) RingLinkState.CONNECTING else RingLinkState.OFF
                    scheduleReconnect()
                }
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            val service = g.getService(SERVICE)
            if (service == null) {
                Log.w(TAG, "R1 service not found; is this an Even R1?")
                g.disconnect()
                return
            }
            pendingSubscriptions = ArrayDeque(NOTIFY_CHARACTERISTICS.mapNotNull { service.getCharacteristic(it) })
            subscribeNext(g)
        }

        override fun onDescriptorWrite(g: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            subscribeNext(g)
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(g: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) characteristic.value?.let(::handleFrame)
        }

        override fun onCharacteristicChanged(g: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            handleFrame(value)
        }
    }

    /** Descriptor writes must be serialized: one CCCD at a time. */
    private fun subscribeNext(g: BluetoothGatt) {
        val next = pendingSubscriptions.removeFirstOrNull()
        if (next == null) {
            backoffMillis = 1_000L
            stateFlow.value = RingLinkState.CONNECTED
            return
        }
        g.setCharacteristicNotification(next, true)
        val descriptor = next.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG)
        if (descriptor == null || !writeDescriptorCompat(g, descriptor)) subscribeNext(g)
    }

    @Suppress("DEPRECATION")
    private fun writeDescriptorCompat(g: BluetoothGatt, descriptor: BluetoothGattDescriptor): Boolean {
        val enable = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                g.writeDescriptor(descriptor, enable) == BluetoothGatt.GATT_SUCCESS
            } else {
                descriptor.value = enable
                g.writeDescriptor(descriptor)
            }
        }.getOrDefault(false)
    }

    private fun handleFrame(raw: ByteArray) {
        val gesture = R1Frame.decode(raw)
        if (gesture == null) {
            lastGestureFlow.value = "unknown " + raw.joinToString(" ") { "%02X".format(it) }
            return
        }
        if (!deduper.accept(gesture)) return
        lastGestureFlow.value = gesture.name
        onGesture?.invoke(gesture)
    }
}
