// Android BLE central for the Even Realities G1 dual-lens glasses.
// Port of ios/Runner/BluetoothManager.swift (CoreBluetooth) onto the Android
// GATT stack, backing g1.G1PacketWriter.
package com.artjiang.helix.ble

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
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.artjiang.helix.g1.G1PacketWriter
import com.artjiang.helix.g1.G1Side
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

/** Per-lens link state surfaced to the UI. */
enum class LensConnectionState { DISCONNECTED, CONNECTING, CONNECTED, READY }

/** A left/right pair discovered during a scan, keyed by the G1 channel number. */
data class DiscoveredPair(
    val channelNumber: String,
    val leftName: String = "",
    val rightName: String = "",
    val leftRssi: Int = 0,
    val rightRssi: Int = 0,
) {
    val displayName: String get() = "G1 - Channel $channelNumber"
    val signalSummary: String get() = "L $leftRssi dBm - R $rightRssi dBm"
    val isComplete: Boolean get() = leftName.isNotEmpty() && rightName.isNotEmpty()
}

/**
 * Dual-connection BLE central.
 *
 * Deviations from BluetoothManager.swift (deliberate fixes):
 *  - **A single-lens disconnect never tears down the other lens.** The Swift
 *    shell emits `glassesDisconnected` for the whole pair on any peripheral
 *    drop; here each side owns its own gatt, state, and reconnect budget, so
 *    losing the right lens leaves the left one live and writable.
 *  - **Bounded auto-reconnect.** Each side reconnects with exponential backoff
 *    up to [MAX_RECONNECT_ATTEMPTS]; the Swift code zeroes the attempt counter
 *    on every disconnect callback, which makes the budget meaningless.
 */
@SuppressLint("MissingPermission") // Guarded by hasPermissions()/needsPermissions.
class G1BluetoothManager(
    context: Context,
    private val scope: CoroutineScope,
) : G1PacketWriter {

    private val appContext = context.applicationContext
    private val bluetoothManager =
        appContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val adapter: BluetoothAdapter? get() = bluetoothManager?.adapter

    // MARK: - Observable state

    private val leftStateFlow = MutableStateFlow(LensConnectionState.DISCONNECTED)
    private val rightStateFlow = MutableStateFlow(LensConnectionState.DISCONNECTED)
    val leftState: StateFlow<LensConnectionState> = leftStateFlow.asStateFlow()
    val rightState: StateFlow<LensConnectionState> = rightStateFlow.asStateFlow()

    private val scanningState = MutableStateFlow(false)
    val isScanning: StateFlow<Boolean> = scanningState.asStateFlow()

    private val discoveredState = MutableStateFlow<List<DiscoveredPair>>(emptyList())
    val discoveredPairs: StateFlow<List<DiscoveredPair>> = discoveredState.asStateFlow()

    private val errorState = MutableStateFlow("")
    val errorMessage: StateFlow<String> = errorState.asStateFlow()

    private val phaseState = MutableStateFlow("Not connected")
    val connectionPhase: StateFlow<String> = phaseState.asStateFlow()

    /** Fired for every inbound notification, with the lens it arrived on. */
    var onInbound: ((ByteArray, G1Side) -> Unit)? = null

    /** Fired when both lenses reach READY — the cue to run the init sequence. */
    var onBothLensesReady: (() -> Unit)? = null

    /** Fired when the pair drops to fully disconnected. */
    var onAllDisconnected: (() -> Unit)? = null

    // MARK: - Per-side link

    private class Link {
        var device: BluetoothDevice? = null
        var gatt: BluetoothGatt? = null
        var writeChar: BluetoothGattCharacteristic? = null
        var notifyChar: BluetoothGattCharacteristic? = null
        var reconnectAttempts: Int = 0
        var userDisconnected: Boolean = false
    }

    private val links = mapOf(G1Side.LEFT to Link(), G1Side.RIGHT to Link())

    // Scan bookkeeping: channel -> (left device, right device)
    private val scannedDevices = mutableMapOf<String, MutableMap<G1Side, BluetoothDevice>>()

    // MARK: - Permissions

    /** True when a runtime permission the BLE path needs is not granted yet. */
    val needsPermissions: Boolean get() = !hasPermissions()

    fun hasPermissions(): Boolean = requiredPermissions().all { permission ->
        ContextCompat.checkSelfPermission(appContext, permission) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Runtime permissions for this API level. BLUETOOTH_SCAN/CONNECT exist only
     * on Android 12 (S, API 31)+; older releases use location for BLE scanning.
     */
    fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    // MARK: - Scanning

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val name = result.scanRecord?.deviceName ?: runCatching { result.device.name }.getOrNull() ?: return
            val parsed = parseG1Name(name) ?: return
            val device = result.device
            val side = if (parsed.side == "L") G1Side.LEFT else G1Side.RIGHT

            scannedDevices.getOrPut(parsed.channelNumber) { mutableMapOf() }[side] = device

            val existing = discoveredState.value.firstOrNull { it.channelNumber == parsed.channelNumber }
                ?: DiscoveredPair(parsed.channelNumber)
            val updated = if (side == G1Side.LEFT) {
                existing.copy(leftName = name, leftRssi = result.rssi)
            } else {
                existing.copy(rightName = name, rightRssi = result.rssi)
            }
            discoveredState.value = discoveredState.value
                .filterNot { it.channelNumber == parsed.channelNumber } + updated
        }

        override fun onScanFailed(errorCode: Int) {
            scanningState.value = false
            errorState.value = "BLE scan failed (code $errorCode)."
        }
    }

    fun startScan() {
        errorState.value = ""
        if (!hasPermissions()) {
            errorState.value = "Bluetooth permission is required to scan."
            return
        }
        val scanner = adapter?.takeIf { it.isEnabled }?.bluetoothLeScanner
        if (scanner == null) {
            errorState.value = "Turn on Bluetooth to scan for glasses."
            return
        }
        discoveredState.value = emptyList()
        scannedDevices.clear()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        // No service-UUID filter: the G1 advertises its UART service only after
        // connecting, so discovery matches on the advertised local name (same
        // as the Swift shell, which scans with `nil` service UUIDs).
        runCatching { scanner.startScan(null, settings, scanCallback) }
            .onSuccess {
                scanningState.value = true
                phaseState.value = "Scanning..."
            }
            .onFailure { errorState.value = it.message ?: "Could not start scanning." }
    }

    fun stopScan() {
        val scanner = adapter?.takeIf { it.isEnabled }?.bluetoothLeScanner
        if (hasPermissions()) runCatching { scanner?.stopScan(scanCallback) }
        scanningState.value = false
        if (leftStateFlow.value == LensConnectionState.DISCONNECTED &&
            rightStateFlow.value == LensConnectionState.DISCONNECTED
        ) {
            phaseState.value = "Not connected"
        }
    }

    // MARK: - Connecting

    fun connect(pair: DiscoveredPair) {
        if (!hasPermissions()) {
            errorState.value = "Bluetooth permission is required to connect."
            return
        }
        stopScan()
        errorState.value = ""
        phaseState.value = "Connecting to ${pair.displayName}..."
        val devices = scannedDevices[pair.channelNumber] ?: run {
            errorState.value = "Glasses are no longer in range; scan again."
            return
        }
        devices[G1Side.LEFT]?.let { connectSide(G1Side.LEFT, it) }
        devices[G1Side.RIGHT]?.let { connectSide(G1Side.RIGHT, it) }
    }

    private fun connectSide(side: G1Side, device: BluetoothDevice) {
        val link = links.getValue(side)
        link.device = device
        link.userDisconnected = false
        setState(side, LensConnectionState.CONNECTING)
        link.gatt?.close()
        link.gatt = device.connectGatt(appContext, false, gattCallbackFor(side), BluetoothDevice.TRANSPORT_LE)
    }

    fun disconnect() {
        links.forEach { (side, link) ->
            link.userDisconnected = true
            link.reconnectAttempts = 0
            runCatching {
                link.gatt?.disconnect()
                link.gatt?.close()
            }
            link.gatt = null
            link.writeChar = null
            link.notifyChar = null
            setState(side, LensConnectionState.DISCONNECTED)
        }
        phaseState.value = "Disconnected"
        onAllDisconnected?.invoke()
    }

    fun clearError() {
        errorState.value = ""
    }

    // MARK: - GATT

    private fun gattCallbackFor(side: G1Side) = object : BluetoothGattCallback() {

        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val link = links.getValue(side)
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    link.reconnectAttempts = 0
                    setState(side, LensConnectionState.CONNECTED)
                    gatt.discoverServices()
                }

                BluetoothProfile.STATE_DISCONNECTED -> {
                    link.writeChar = null
                    link.notifyChar = null
                    runCatching { gatt.close() }
                    link.gatt = null
                    setState(side, LensConnectionState.DISCONNECTED)
                    // This side only — the other lens keeps its link alive.
                    if (!link.userDisconnected) scheduleReconnect(side)
                    updatePhase()
                    if (leftStateFlow.value == LensConnectionState.DISCONNECTED &&
                        rightStateFlow.value == LensConnectionState.DISCONNECTED
                    ) {
                        onAllDisconnected?.invoke()
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) return
            val service = gatt.getService(UART_SERVICE) ?: return
            val link = links.getValue(side)
            link.writeChar = service.getCharacteristic(UART_TX_CHARACTERISTIC)
            link.notifyChar = service.getCharacteristic(UART_RX_CHARACTERISTIC)

            val notifyChar = link.notifyChar ?: return
            gatt.setCharacteristicNotification(notifyChar, true)
            notifyChar.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG)?.let { descriptor ->
                writeDescriptorCompat(gatt, descriptor)
            }
            setState(side, LensConnectionState.READY)
            updatePhase()
            if (leftStateFlow.value == LensConnectionState.READY &&
                rightStateFlow.value == LensConnectionState.READY
            ) {
                onBothLensesReady?.invoke()
            }
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            // Pre-Android 13 callback: value lives on the characteristic.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                characteristic.value?.let { onInbound?.invoke(it, side) }
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            onInbound?.invoke(value, side)
        }
    }

    @Suppress("DEPRECATION")
    private fun writeDescriptorCompat(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor) {
        val enable = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeDescriptor(descriptor, enable)
        } else {
            descriptor.value = enable
            gatt.writeDescriptor(descriptor)
        }
    }

    private fun scheduleReconnect(side: G1Side) {
        val link = links.getValue(side)
        val device = link.device ?: return
        if (link.reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) return
        link.reconnectAttempts += 1
        val attempt = link.reconnectAttempts
        scope.launch {
            // Exponential backoff: 1s, 2s, 4s.
            delay(RECONNECT_BASE_DELAY_MILLIS shl (attempt - 1))
            if (link.userDisconnected) return@launch
            if (leftStateFlow.value == LensConnectionState.READY && side == G1Side.LEFT) return@launch
            if (rightStateFlow.value == LensConnectionState.READY && side == G1Side.RIGHT) return@launch
            if (!hasPermissions()) return@launch
            setState(side, LensConnectionState.CONNECTING)
            link.gatt = device.connectGatt(appContext, false, gattCallbackFor(side), BluetoothDevice.TRANSPORT_LE)
        }
    }

    // MARK: - G1PacketWriter

    @Suppress("DEPRECATION")
    override suspend fun write(bytes: ByteArray, side: G1Side): Boolean {
        val link = links.getValue(side)
        val gatt = link.gatt ?: return false
        val characteristic = link.writeChar ?: return false
        if (!hasPermissions()) return false

        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeCharacteristic(
                    characteristic,
                    bytes,
                    BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE,
                ) == BluetoothGatt.GATT_SUCCESS
            } else {
                characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                characteristic.value = bytes
                gatt.writeCharacteristic(characteristic)
            }
        }.getOrDefault(false)
    }

    // MARK: - Helpers

    private fun setState(side: G1Side, state: LensConnectionState) {
        when (side) {
            G1Side.LEFT -> leftStateFlow.value = state
            G1Side.RIGHT -> rightStateFlow.value = state
        }
    }

    private fun updatePhase() {
        val left = leftStateFlow.value
        val right = rightStateFlow.value
        phaseState.value = when {
            left == LensConnectionState.READY && right == LensConnectionState.READY -> "Connected"
            left == LensConnectionState.READY -> "Connected (left lens)"
            right == LensConnectionState.READY -> "Connected (right lens)"
            left == LensConnectionState.CONNECTING || right == LensConnectionState.CONNECTING -> "Connecting..."
            else -> "Not connected"
        }
    }

    /** Parsed `<prefix>_<side>_<channel>` (or `<channel>_<side>`) advert name. */
    internal data class ParsedName(val channelNumber: String, val side: String)

    companion object {
        val UART_SERVICE: UUID = UUID.fromString("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        val UART_TX_CHARACTERISTIC: UUID = UUID.fromString("6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
        val UART_RX_CHARACTERISTIC: UUID = UUID.fromString("6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
        val CLIENT_CHARACTERISTIC_CONFIG: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")

        const val MAX_RECONNECT_ATTEMPTS = 3
        const val RECONNECT_BASE_DELAY_MILLIS = 1_000L

        /**
         * Exact port of `parseG1PeripheralName` in BluetoothManager.swift:
         * split on "_", find the "L"/"R" token, then prefer an all-digit
         * neighbour as the channel number (before, then after), falling back to
         * whichever neighbour exists.
         */
        internal fun parseG1Name(name: String): ParsedName? {
            val components = name.split("_").filter { it.isNotEmpty() }
            val sideIndex = components.indexOfFirst { it == "L" || it == "R" }
            if (sideIndex < 0) return null
            val side = components[sideIndex]
            val previous = (sideIndex - 1).takeIf { it >= 0 }?.let { components[it] }
            val next = (sideIndex + 1).takeIf { it < components.size }?.let { components[it] }

            previous?.takeIf(::isLikelyChannelNumber)?.let { return ParsedName(it, side) }
            next?.takeIf(::isLikelyChannelNumber)?.let { return ParsedName(it, side) }
            previous?.let { return ParsedName(it, side) }
            next?.let { return ParsedName(it, side) }
            return null
        }

        private fun isLikelyChannelNumber(value: String): Boolean =
            value.isNotEmpty() && value.all { it.isDigit() }
    }
}
