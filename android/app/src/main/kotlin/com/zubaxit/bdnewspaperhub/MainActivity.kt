package com.zubaxit.bdnewspaperhub

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "amar_news/reader_tts"

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4102
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        TtsPlaybackService.eventSink = { event ->
            runOnUiThread { channel.invokeMethod("ttsEvent", event) }
        }
        channel.setMethodCallHandler { call, result ->
            if (call.method == "state") {
                result.success(TtsPlaybackService.snapshot())
                return@setMethodCallHandler
            }
            if (call.method == "speak" &&
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST,
                )
            }
            val intent = Intent(this, TtsPlaybackService::class.java).apply {
                action = "com.zubaxit.bdnewspaperhub.TTS_COMMAND"
                putExtra("command", call.method)
                when (call.method) {
                    "speak" -> {
                        putExtra("articleId", call.argument<String>("articleId"))
                        putExtra("text", call.argument<String>("text"))
                        putExtra("language", call.argument<String>("language") ?: "en-US")
                        putExtra("rate", call.argument<Double>("rate") ?: 1.0)
                        putExtra("offset", call.argument<Int>("startOffset") ?: 0)
                    }
                    "seek" -> putExtra("offset", call.argument<Int>("offset") ?: 0)
                    "setRate" -> putExtra("rate", call.argument<Double>("rate") ?: 1.0)
                }
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ContextCompat.startForegroundService(this, intent)
                } else {
                    startService(intent)
                }
                result.success(null)
            } catch (error: Exception) {
                result.error("tts_start_failed", error.message, null)
            }
        }
    }

    override fun onDestroy() {
        TtsPlaybackService.eventSink = null
        super.onDestroy()
    }
}
