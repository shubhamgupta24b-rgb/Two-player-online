package com.example.multiplayer_game

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Plays the game music (looping, MediaPlayer) and sound effects (SoundPool) that the Dart
/// side synthesises as WAV bytes (lib/core/audio/game_audio.dart). Each sound is sent once
/// and kept in the cache folder; later calls only name it.
class MainActivity : FlutterActivity() {
    private var music: MediaPlayer? = null
    private var musicVolume = 0.6f
    private val pool: SoundPool = SoundPool.Builder()
        .setMaxStreams(6)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()
    private val effects = HashMap<String, Int>()
    private val ready = HashSet<Int>()
    private val waiting = HashMap<Int, Float>()

    init {
        pool.setOnLoadCompleteListener { p, id, status ->
            if (status != 0) return@setOnLoadCompleteListener
            ready.add(id)
            waiting.remove(id)?.let { v -> p.play(id, v, v, 1, 0, 1f) }
        }
    }

    private var hapticsOn = true

    /// Every view in the window (Flutter's included) stops vibrating when [hapticsOn] is off;
    /// HapticFeedback calls from Dart go through View.performHapticFeedback, which honours it.
    private fun applyHaptics(v: android.view.View = window.decorView) {
        v.isHapticFeedbackEnabled = hapticsOn
        if (v is android.view.ViewGroup) for (i in 0 until v.childCount) applyHaptics(v.getChildAt(i))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "party/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "haptics" -> {
                    hapticsOn = call.argument<Boolean>("on") ?: true
                    applyHaptics()
                    result.success(null)
                }
                // Share a room code (or any text) with the system share sheet.
                "share" -> {
                    val send = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(android.content.Intent.EXTRA_TEXT, call.argument<String>("text") ?: "")
                    }
                    startActivity(android.content.Intent.createChooser(send, null))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "party/audio").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "music" -> {
                        val file = save("music_${call.argument<String>("name")}.wav", call.argument<ByteArray>("bytes"))
                        musicVolume = (call.argument<Double>("volume") ?: 0.6).toFloat()
                        stopMusic()
                        music = MediaPlayer().apply {
                            setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                            setDataSource(file.path)
                            isLooping = true
                            setVolume(musicVolume, musicVolume)
                            prepare()
                            start()
                        }
                    }
                    "stopMusic" -> stopMusic()
                    "volume" -> {
                        musicVolume = (call.argument<Double>("volume") ?: 0.6).toFloat()
                        music?.setVolume(musicVolume, musicVolume)
                    }
                    "sfx" -> {
                        val name = call.argument<String>("name")!!
                        val v = (call.argument<Double>("volume") ?: 1.0).toFloat()
                        val bytes = call.argument<ByteArray>("bytes")
                        var id = effects[name]
                        if (id == null && bytes != null) {
                            id = pool.load(save("sfx_$name.wav", bytes).path, 1)
                            effects[name] = id
                        }
                        if (id != null) {
                            if (ready.contains(id)) pool.play(id, v, v, 1, 0, 1f) else waiting[id] = v
                        }
                    }
                }
                result.success(null)
            } catch (e: Exception) {
                result.error("audio", e.message, null)
            }
        }
    }

    private fun save(name: String, bytes: ByteArray?): File {
        val file = File(cacheDir, name)
        if (bytes != null) file.writeBytes(bytes)
        return file
    }

    private fun stopMusic() {
        music?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
            }
            it.release()
        }
        music = null
    }

    // Quiet while the app is in the background.
    override fun onPause() {
        super.onPause()
        music?.let { if (it.isPlaying) it.pause() }
    }

    override fun onResume() {
        super.onResume()
        music?.start()
        applyHaptics()
    }

    override fun onDestroy() {
        stopMusic()
        pool.release()
        super.onDestroy()
    }
}
