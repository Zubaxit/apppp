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
    private var pendingVocabularyExport: MethodChannel.Result? = null
    private var pendingVocabularyContents: String? = null

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4102
        private const val CREATE_VOCABULARY_DOCUMENT_REQUEST = 4103
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        TtsPlaybackService.eventSink = { event ->
            runOnUiThread { channel.invokeMethod("ttsEvent", event) }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "amar_news/vocabulary_transfer",
        ).setMethodCallHandler { call, result ->
            if (call.method != "export") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingVocabularyExport != null) {
                result.error("export_busy", "A document picker is already open.", null)
                return@setMethodCallHandler
            }
            val contents = call.argument<String>("contents")
            if (contents == null) {
                result.error("export_invalid", "No vocabulary data was provided.", null)
                return@setMethodCallHandler
            }
            pendingVocabularyExport = result
            pendingVocabularyContents = contents
            startActivityForResult(
                Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/json"
                    putExtra(
                        Intent.EXTRA_TITLE,
                        call.argument<String>("suggestedName")
                            ?: "amar-news-vocabulary.json",
                    )
                },
                CREATE_VOCABULARY_DOCUMENT_REQUEST,
            )
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

    @Deprecated("Uses the stable Android document contract across supported SDKs")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CREATE_VOCABULARY_DOCUMENT_REQUEST) return
        val result = pendingVocabularyExport
        val contents = pendingVocabularyContents
        pendingVocabularyExport = null
        pendingVocabularyContents = null
        if (result == null) return
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (uri == null) {
            result.success(false)
            return
        }
        try {
            val stream = contentResolver.openOutputStream(uri, "wt")
                ?: throw IllegalStateException(
                    "The selected document cannot be opened for writing.",
                )
            stream.bufferedWriter(Charsets.UTF_8).use { writer ->
                writer.write(contents ?: "")
                writer.flush()
            }
            result.success(true)
        } catch (error: Exception) {
            result.error("export_write_failed", error.message, null)
        }
    }

    override fun onDestroy() {
        pendingVocabularyExport = null
        pendingVocabularyContents = null
        TtsPlaybackService.eventSink = null
        super.onDestroy()
    }
}
