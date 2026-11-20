package com.aetherscan.pro.aetherscan_pro

import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.Locale
import kotlin.concurrent.thread
import kotlin.math.abs
import kotlin.math.sqrt
import kotlin.random.Random

class MainActivity : FlutterActivity(), SensorEventListener {
    private val CHANNEL        = "com.aetherscan.pro/audio"
    private val SENSOR_CHANNEL = "com.aetherscan.pro/sensors"
    private val PREFS_NAME     = "AetherScanProPrefs"
    private val PREF_KEY_LICENSE = "saved_license_key"

    private var staticTrack: AudioTrack? = null
    private var isStaticPlaying = false
    private var staticCoupling: Float = 0.0f
    private var staticPitchHz: Float = 600.0f
    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    private var masterVolume: Float = 0.85f

    // Sensori
    private lateinit var sensorManager: SensorManager
    private var sensorEventSink: EventChannel.EventSink? = null
    private var emfBaseline: Double = -1.0
    private var emfSpikeActive = false
    private var lastProximityNear = false

    // Rilevamento tocco / sfioramento intelligente (anti-falsi positivi impugnatura)
    private val gravity = FloatArray(3)
    private var lastTouchTriggerTime = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager

        // Inizializzazione TTS offline nativo
        try {
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    val res = tts?.setLanguage(Locale.ITALIAN)
                    isTtsReady = res != TextToSpeech.LANG_MISSING_DATA && res != TextToSpeech.LANG_NOT_SUPPORTED
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── MethodChannel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceHwid" -> {
                    val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "UNKNOWN_DEV"
                    val md5 = MessageDigest.getInstance("MD5")
                    val digest = md5.digest("ANDROID:$androidId".toByteArray())
                    val hwid = digest.joinToString("") { "%02x".format(it) }
                    result.success(hwid)
                }
                "getSavedLicense" -> {
                    // App 100% gratuita e offline standalone
                    result.success("FREE_OFFLINE_STANDALONE")
                }
                "saveLicense" -> {
                    result.success(true)
                }
                "playModulatedStatic" -> {
                    val coupling = call.argument<Double>("coupling") ?: 0.0
                    val pitchHz = call.argument<Double>("pitchHz") ?: 600.0
                    updateStaticModulation(coupling.toFloat(), pitchHz.toFloat())
                    result.success(true)
                }
                "setVolume" -> {
                    val vol = (call.argument<Double>("volume") ?: 0.85).toFloat()
                    masterVolume = vol.coerceIn(0.0f, 1.0f)
                    result.success(true)
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val vol = (call.argument<Double>("volume") ?: 1.0).toFloat()
                    val pitch = (call.argument<Double>("pitch") ?: 1.0).toFloat()
                    speakText(text, vol, pitch)
                    result.success(true)
                }
                "playBeep" -> {
                    val freq = call.argument<Int>("freq") ?: 880
                    val durationMs = call.argument<Int>("durationMs") ?: 100
                    playTone(freq, durationMs)
                    result.success(true)
                }
                "playChime" -> { playChimeSound(); result.success(true) }
                "playProximityAlert" -> { playProximityAlert(); result.success(true) }
                "playEmfAlert" -> { playEmfAlert(); result.success(true) }
                "startStatic" -> {
                    val vol = call.argument<Double>("volume")
                    if (vol != null) {
                        masterVolume = vol.toFloat().coerceIn(0.0f, 1.0f)
                    }
                    startRadioStatic()
                    result.success(true)
                }
                "updateStaticParams" -> {
                    val dEmf   = call.argument<Double>("emfDelta") ?: 0.0
                    val accel  = call.argument<Double>("accel") ?: 0.0
                    val zScore = call.argument<Double>("zScore") ?: 0.0
                    val vol    = call.argument<Double>("volume")
                    if (vol != null) {
                        masterVolume = vol.toFloat().coerceIn(0.0f, 1.0f)
                    }
                    updateStaticChaosParams(dEmf, accel, zScore)
                    result.success(true)
                }
                "stopStatic"  -> { stopRadioStatic(); result.success(true) }
                "audioDiagnostic" -> {
                    result.success(buildDiagnostic())
                }
                "setWakeLock" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    runOnUiThread {
                        if (enabled) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }
                "openUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                        result.success(true)
                    } catch (e: Exception) { result.success(false) }
                }
                else -> result.notImplemented()
            }
        }

        // ── EventChannel (sensori) ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SENSOR_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sensorEventSink = events
                    startSensors()
                }
                override fun onCancel(arguments: Any?) {
                    stopSensors()
                    sensorEventSink = null
                }
            })
    }

    // ──────────────────────────────────────────────────────────────────
    // Diagnostica Audio e Sensori Android
    // ──────────────────────────────────────────────────────────────────
    private fun buildDiagnostic(): String {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        // Check sensor availability via sensorManager
        val proximityAvailable = sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY) != null
        val magAvailable = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null
        val accelAvailable = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null
        return """
=== DIAGNOSTICA AETHERSCAN (ANDROID) ===
Channel registrato: true
Volume Stream Music: $currentVol / $maxVol
Licenza: 100% Gratuita / Illimitata (Offline Standalone)
Prossimita: ${if (proximityAvailable) "DISPONIBILE" else "NON DISPONIBILE"}
Magnetometro (EMF): ${if (magAvailable) "DISPONIBILE" else "NON DISPONIBILE"}
Sensore Tocco (Accel): ${if (accelAvailable) "DISPONIBILE" else "NON DISPONIBILE"}
EMF Baseline: ${if (emfBaseline < 0) "-1.0" else String.format(java.util.Locale.US, "%.1f", emfBaseline)} uT
""".trimIndent()
    }

    // ──────────────────────────────────────────────────────────────────
    // Gestione Sensori
    // ──────────────────────────────────────────────────────────────────
    private fun startSensors() {
        sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
        sensorManager.getDefaultSensor(Sensor.TYPE_PRESSURE)?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun stopSensors() {
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return
        when (event.sensor.type) {
            Sensor.TYPE_PROXIMITY -> {
                val maxRange = event.sensor.maximumRange
                val near = event.values[0] < (maxRange / 2f)
                if (near != lastProximityNear) {
                    lastProximityNear = near
                    runOnUiThread {
                        sensorEventSink?.success(mapOf("type" to "proximity", "near" to near))
                    }
                }
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                val x = event.values[0].toDouble()
                val y = event.values[1].toDouble()
                val z = event.values[2].toDouble()
                val magnitude = sqrt(x*x + y*y + z*z)

                if (emfBaseline < 0) {
                    emfBaseline = magnitude
                    return
                }

                val delta = abs(magnitude - emfBaseline)
                val spikeThreshold = 25.0

                val isSpike: Boolean
                if (delta > spikeThreshold && !emfSpikeActive) {
                    emfSpikeActive = true
                    isSpike = true
                } else if (delta <= spikeThreshold * 0.5) {
                    emfSpikeActive = false
                    isSpike = false
                } else {
                    isSpike = false
                }

                emfBaseline = emfBaseline * 0.98 + magnitude * 0.02

                runOnUiThread {
                    sensorEventSink?.success(mapOf(
                        "type" to "emf",
                        "value" to magnitude,
                        "delta" to delta,
                        "spike" to isSpike
                    ))
                }
            }
            Sensor.TYPE_ACCELEROMETER -> {
                // Filtro passa-basso per la gravità (orientamento/movimento lento mano: alpha = 0.85)
                val alpha = 0.85f
                gravity[0] = alpha * gravity[0] + (1 - alpha) * event.values[0]
                gravity[1] = alpha * gravity[1] + (1 - alpha) * event.values[1]
                gravity[2] = alpha * gravity[2] + (1 - alpha) * event.values[2]

                // Lineare (passa-alto): componente istantanea di accelerazione/impulso
                val linearX = event.values[0] - gravity[0]
                val linearY = event.values[1] - gravity[1]
                val linearZ = event.values[2] - gravity[2]
                val impulse = sqrt((linearX * linearX + linearY * linearY + linearZ * linearZ).toDouble())

                runOnUiThread {
                    sensorEventSink?.success(mapOf(
                        "type" to "accel",
                        "dynamic_magnitude" to impulse,
                        "x" to linearX.toDouble(),
                        "y" to linearY.toDouble(),
                        "z" to linearZ.toDouble()
                    ))
                }

                // Soglia tarata: 3.2 m/s² (sensibile al tocco/sfioramento, ma ignora oscillazioni lente della mano)
                // Cooldown anti-rimbalzo allineato Android/iOS: 2.0 s (2000 ms)
                val now = System.currentTimeMillis()
                if (impulse > 3.2 && (now - lastTouchTriggerTime > 2000L)) {
                    lastTouchTriggerTime = now
                    runOnUiThread {
                        sensorEventSink?.success(mapOf(
                            "type" to "touch",
                            "intensity" to impulse
                        ))
                    }
                }
            }
            Sensor.TYPE_PRESSURE -> {
                val hPa = event.values[0].toDouble()
                runOnUiThread {
                    sensorEventSink?.success(mapOf(
                        "type" to "pressure",
                        "value" to hPa
                    ))
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    // ──────────────────────────────────────────────────────────────────
    // Audio Sintetico (Beep / Chime / Prossimità / EMF)
    // ──────────────────────────────────────────────────────────────────
    private fun playTone(freqHz: Int, durationMs: Int) {
        thread {
            try {
                val sampleRate = 22050
                val numSamples = (sampleRate * (durationMs / 1000.0)).toInt()
                val samples = ShortArray(numSamples)
                val toneGain = if (masterVolume < 0.05f) 0.0 else (masterVolume * masterVolume).toDouble()
                for (i in 0 until numSamples) {
                    val angle = 2.0 * Math.PI * i * freqHz / sampleRate
                    val env = 1.0 - (i.toDouble() / numSamples)
                    samples[i] = (Math.sin(angle) * Short.MAX_VALUE * 0.4 * env * toneGain).toInt().toShort()
                }
                val track = AudioTrack(
                    AudioManager.STREAM_MUSIC, sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    numSamples * 2, AudioTrack.MODE_STATIC
                )
                track.write(samples, 0, numSamples)
                track.play()
                Thread.sleep(durationMs.toLong() + 50)
                track.release()
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    private fun playChimeSound() {
        thread {
            for (f in intArrayOf(650, 950, 1300)) { playTone(f, 90); Thread.sleep(85) }
        }
    }

    private fun playProximityAlert() {
        thread {
            for (f in intArrayOf(1200, 900, 1200, 900)) { playTone(f, 80); Thread.sleep(120) }
        }
    }

    private fun playEmfAlert() {
        thread {
            for (f in intArrayOf(200, 220, 200)) { playTone(f, 150); Thread.sleep(180) }
        }
    }

    // == Parametri chaos DSP aggiornabili in tempo reale dai sensori ==
    @Volatile private var chaosDeltaEmf: Double = 0.0
    @Volatile private var chaosAccel: Double = 0.0
    @Volatile private var chaosZScore: Double = 0.0

    // == Motore radio-static caotico deterministico (Logistic Map + Biquad IIR) ==
    // ZERO Random() - tutta la sintesi e deterministica pilotata dai sensori fisici
    private fun startRadioStatic() {
        if (isStaticPlaying) return
        isStaticPlaying = true
        thread {
            try {
                val sampleRate = 22050
                val minBuf = AudioTrack.getMinBufferSize(
                    sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
                val bufSize = maxOf(minBuf, 2048)
                val buffer = ShortArray(bufSize)
                staticTrack = AudioTrack(
                    AudioManager.STREAM_MUSIC, sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    bufSize, AudioTrack.MODE_STREAM
                )
                staticTrack?.play()

                // Stato oscillatore caotico logistic map
                var logX = 0.5          // condizione iniziale deterministica
                var phase = 0.0         // fase FM accumulata
                var tremoloPhase = 0.0  // fase tremolo AM da accelerometro
                val dt = 1.0 / sampleRate

                // Stato filtro biquad passabanda dinamico
                var bqX1 = 0.0; var bqX2 = 0.0
                var bqY1 = 0.0; var bqY2 = 0.0
                var bqB0 = 1.0; var bqB2 = -1.0
                var bqA1 = 0.0; var bqA2 = 0.0

                fun updateBiquad(cutHz: Double, q: Double) {
                    val omega = 2.0 * Math.PI * cutHz / sampleRate
                    val sinW = kotlin.math.sin(omega)
                    val cosW = kotlin.math.cos(omega)
                    val alpha = sinW / (2.0 * q)
                    val a0inv = 1.0 / (1.0 + alpha)
                    bqB0 =  alpha * a0inv
                    bqB2 = -alpha * a0inv
                    bqA1 = -2.0 * cosW * a0inv
                    bqA2 = (1.0 - alpha) * a0inv
                }

                while (isStaticPlaying) {
                    val dEmf   = chaosDeltaEmf
                    val accel  = chaosAccel
                    val zScore = chaosZScore

                    // r del logistic map: 3.57 (quasi-periodico) -> 4.0 (caos pieno)
                    val rParam = (3.72 + kotlin.math.abs(dEmf) * 0.08).coerceIn(3.57, 4.0)

                    // Coupling sensoriale [0.0 - 1.0]
                    val coupling = (kotlin.math.abs(zScore) / 4.0 + accel / 3.0).coerceIn(0.0, 1.0)

                    // Frequenza portante eterodina dalla sintonia corrente
                    val baseCarrierHz = staticPitchHz.toDouble().coerceIn(200.0, 2000.0)
                    val emfFmShift = dEmf * 120.0  // Hz per uT di deviazione

                    // Biquad dinamico: cutoff e Q inseguono l'energia sensoriale
                    val cutoffHz = (800.0 + kotlin.math.abs(zScore) * 280.0).coerceIn(200.0, 3000.0)
                    val qFactor  = (1.0 + accel * 2.5).coerceIn(0.5, 8.0)
                    updateBiquad(cutoffHz, qFactor)

                    // Tremolo AM da accelerometro
                    val tremoloRateHz = (0.5 + kotlin.math.abs(accel) * 2.5).coerceIn(0.5, 6.0)
                    val tremoloDepth  = (0.15 + coupling * 0.45).coerceIn(0.15, 0.6)

                    val effectiveGain = if (masterVolume < 0.05f) 0.0 else (masterVolume * masterVolume).toDouble()
                    for (i in buffer.indices) {
                        // 1. Oscillatore caotico logistic map
                        logX = rParam * logX * (1.0 - logX)
                        if (logX.isNaN() || logX.isInfinite()) logX = 0.5
                        val chaosRaw = logX * 2.0 - 1.0  // [-1, +1]

                        // 2. FM: fase accumulata sample-by-sample
                        phase += (baseCarrierHz + emfFmShift) * dt
                        if (phase > 1e6) phase -= 1e6
                        val carrier = kotlin.math.sin(2.0 * Math.PI * phase)

                        // 3. Tremolo AM da accelerometro
                        tremoloPhase += tremoloRateHz * dt
                        if (tremoloPhase > 1e6) tremoloPhase -= 1e6
                        val tremolo = 1.0 - tremoloDepth * (0.5 + 0.5 * kotlin.math.sin(2.0 * Math.PI * tremoloPhase))

                        // 4. Miscela caos + carrier + tremolo
                        val mixed = (chaosRaw * (1.0 - coupling * 0.6) + carrier * coupling * 0.4) * tremolo

                        // 5. Filtro biquad IIR passabanda
                        val filtered = bqB0 * mixed + bqB2 * bqX2 - bqA1 * bqY1 - bqA2 * bqY2
                        bqX2 = bqX1; bqX1 = mixed
                        bqY2 = bqY1; bqY1 = filtered

                        buffer[i] = (filtered * 22000.0 * effectiveGain).toInt().coerceIn(-32767, 32767).toShort()
                    }
                    staticTrack?.write(buffer, 0, buffer.size)
                }
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    private fun updateStaticModulation(coupling: Float, pitchHz: Float) {
        staticCoupling = coupling
        staticPitchHz = pitchHz
    }

    private fun updateStaticChaosParams(deltaEmf: Double, accel: Double, zScore: Double) {
        chaosDeltaEmf = deltaEmf
        chaosAccel    = accel
        chaosZScore   = zScore
    }

    private fun stopRadioStatic() {
        isStaticPlaying = false
        try { staticTrack?.stop(); staticTrack?.release(); staticTrack = null }
        catch (e: Exception) { e.printStackTrace() }
    }

    private fun speakText(text: String, vol: Float, pitch: Float) {
        if (tts != null && isTtsReady && text.isNotBlank()) {
            try {
                tts?.setPitch(pitch)
                val params = Bundle()
                val effectiveVol = (vol * masterVolume).coerceIn(0.0f, 1.0f)
                params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, effectiveVol)
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "AETHER_VOCAL_${System.currentTimeMillis()}")
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onDestroy() {
        stopSensors()
        stopRadioStatic()
        try {
            tts?.stop()
            tts?.shutdown()
            tts = null
        } catch (e: Exception) { e.printStackTrace() }
        super.onDestroy()
    }
}
