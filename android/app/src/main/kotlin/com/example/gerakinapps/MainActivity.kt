package com.example.gerakinapps

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    // [PBI-7.9] Pemutar nada pendek untuk timer interval. SystemSound.alert
    // diabaikan oleh Flutter di Android, jadi nada dibuat lewat ToneGenerator.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gerakin/beep")
            .setMethodCallHandler { call, result ->
                if (call.method == "beep") {
                    val durationMs = call.argument<Int>("durationMs") ?: 150
                    try {
                        val tone = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
                        tone.startTone(ToneGenerator.TONE_PROP_BEEP, durationMs)
                        Handler(Looper.getMainLooper()).postDelayed(
                            { tone.release() },
                            durationMs.toLong() + 100
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("BEEP_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}