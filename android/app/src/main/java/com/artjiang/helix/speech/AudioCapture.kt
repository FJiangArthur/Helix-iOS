// Raw microphone PCM for the OpenAI Realtime transcriber. Android's
// SpeechRecognizer owns its own audio path, so this is the first place the
// app touches AudioRecord directly.
package com.artjiang.helix.speech

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Process

/**
 * Mono PCM16 microphone source. [sampleRateHz] is the rate the device
 * actually opened at — valid after [start] — so the consumer can resample
 * to what the remote session expects.
 */
interface AudioCapture {
    val sampleRateHz: Int

    /**
     * Begins delivering frames on a capture thread. [onPcm] receives a reused
     * buffer plus the valid sample count; copy what you keep. [onError] fires
     * once on an unrecoverable read failure, after which capture stops.
     */
    fun start(onPcm: (ShortArray, Int) -> Unit, onError: (String) -> Unit)

    fun stop()
}

/**
 * [AudioRecord]-backed capture. Tries the rates the realtime session wants
 * most (24 kHz native means no resampling) before the ones every device
 * supports; reads 20 ms frames on a dedicated urgent-audio thread.
 *
 * Audio source is plain [MediaRecorder.AudioSource.MIC]: the remote model
 * does its own cleanup, and on-device voice processing (VOICE_COMMUNICATION)
 * has been observed to clip speech before it reaches the recognizer.
 */
class AudioRecordCapture : AudioCapture {

    @Volatile
    override var sampleRateHz: Int = RealtimeEvents.SAMPLE_RATE
        private set

    private var record: AudioRecord? = null
    private var thread: Thread? = null

    @Volatile
    private var running = false

    @SuppressLint("MissingPermission") // RECORD_AUDIO is requested by the shell before start().
    override fun start(onPcm: (ShortArray, Int) -> Unit, onError: (String) -> Unit) {
        if (running) return
        val opened = openRecord() ?: run {
            onError("Could not open the microphone. Check that no other app is recording.")
            return
        }
        val (instance, rate) = opened
        record = instance
        sampleRateHz = rate
        running = true
        val frame = ShortArray(rate / 50) // 20 ms
        thread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            runCatching { instance.startRecording() }.onFailure {
                running = false
                onError("Microphone failed to start: ${it.message ?: it::class.simpleName}")
                return@Thread
            }
            while (running) {
                val read = instance.read(frame, 0, frame.size)
                if (read < 0) {
                    running = false
                    onError("Microphone read failed (code $read).")
                    break
                }
                if (read > 0) onPcm(frame, read)
            }
        }, "helix-audio-capture").also { it.start() }
    }

    override fun stop() {
        running = false
        thread?.let { t -> runCatching { t.join(500) } }
        thread = null
        record?.let { r ->
            runCatching { if (r.recordingState == AudioRecord.RECORDSTATE_RECORDING) r.stop() }
            runCatching { r.release() }
        }
        record = null
    }

    @SuppressLint("MissingPermission")
    private fun openRecord(): Pair<AudioRecord, Int>? {
        for (rate in PREFERRED_RATES) {
            val minBuffer = AudioRecord.getMinBufferSize(rate, CHANNEL, ENCODING)
            if (minBuffer <= 0) continue
            val quarterSecond = rate / 4 * 2 // bytes for 250 ms of PCM16 mono
            val bufferBytes = maxOf(minBuffer * 2, quarterSecond)
            val candidate = runCatching {
                AudioRecord(MediaRecorder.AudioSource.MIC, rate, CHANNEL, ENCODING, bufferBytes)
            }.getOrNull() ?: continue
            if (candidate.state == AudioRecord.STATE_INITIALIZED) return candidate to rate
            runCatching { candidate.release() }
        }
        return null
    }

    companion object {
        /** 24 kHz first (session-native), then the universally supported rates. */
        val PREFERRED_RATES: List<Int> = listOf(24_000, 16_000, 48_000, 44_100)
        private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }
}
