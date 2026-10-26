package com.zubaxit.bdnewspaperhub

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import androidx.media.session.MediaButtonReceiver
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

class TtsPlaybackService : Service(), TextToSpeech.OnInitListener {
    companion object {
        const val notificationId = 4107
        const val notificationChannel = "amar_news_listen"
        var eventSink: ((Map<String, Any?>) -> Unit)? = null
        private var articleId: String? = null
        private var text: String = ""
        private var language: String = "en-US"
        private var rate: Float = 1f
        private var offset: Int = 0
        private var state: String = "idle"

        fun snapshot(): Map<String, Any?> = mapOf(
            "articleId" to articleId,
            "offset" to offset,
            "rate" to rate,
            "state" to state,
        )
    }

    private lateinit var tts: TextToSpeech
    private lateinit var mediaSession: MediaSessionCompat
    private lateinit var audioManager: AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private var initialized = false
    private var queued: Intent? = null
    private var baseOffset = 0
    private var resumeAfterFocus = false

    override fun onCreate() {
        super.onCreate()
        instanceNotificationChannel()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        mediaSession = MediaSessionCompat(this, "AmarNewsReader").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = resumeSpeech()
                override fun onPause() = pauseSpeech()
                override fun onStop() = stopSpeech()
                override fun onSkipToNext() = seekBySentence(1)
                override fun onSkipToPrevious() = seekBySentence(-1)
            })
            isActive = true
        }
        tts = TextToSpeech(this, this)
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                state = "playing"
                emit("playing")
                updateSession()
            }
            override fun onDone(utteranceId: String?) {
                offset = text.length
                state = "completed"
                emit("completed")
                updateSession()
                abandonFocus()
                stopForeground(false)
            }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) = failure("Android TTS could not speak this article.")
            override fun onError(utteranceId: String?, errorCode: Int) =
                failure("Android TTS stopped with error $errorCode.")
            override fun onRangeStart(utteranceId: String?, start: Int, end: Int, frame: Int) {
                offset = min(text.length, baseOffset + start)
                emit("progress", mapOf("end" to min(text.length, baseOffset + end)))
                updateSession()
            }
        })
        startForeground(notificationId, notification())
    }

    override fun onInit(status: Int) {
        initialized = status == TextToSpeech.SUCCESS
        if (!initialized) {
            failure("Android's text-to-speech engine is unavailable.")
            return
        }
        queued?.also {
            queued = null
            handle(it)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            if (!initialized && intent.getStringExtra("command") == "speak") queued = intent
            else handle(intent)
        }
        return START_STICKY
    }

    private fun handle(intent: Intent) {
        when (intent.getStringExtra("command")) {
            "speak" -> {
                val nextId = intent.getStringExtra("articleId") ?: return
                val nextText = intent.getStringExtra("text") ?: return
                tts.stop()
                articleId = nextId
                text = nextText
                language = intent.getStringExtra("language") ?: "en-US"
                rate = intent.getDoubleExtra("rate", 1.0).toFloat()
                offset = intent.getIntExtra("offset", 0).coerceIn(0, text.length)
                speakFrom(offset)
            }
            "pause" -> pauseSpeech()
            "resume" -> resumeSpeech()
            "stop" -> stopSpeech()
            "seek" -> {
                offset = intent.getIntExtra("offset", offset).coerceIn(0, text.length)
                if (state == "playing") speakFrom(offset) else emit("paused")
            }
            "nativeBack" -> seekBySentence(-1)
            "nativeForward" -> seekBySentence(1)
            "setRate" -> {
                rate = intent.getDoubleExtra("rate", 1.0).toFloat()
                if (state == "playing") speakFrom(offset)
                updateSession()
            }
        }
    }

    private fun speakFrom(start: Int) {
        if (!initialized || text.isEmpty()) return
        val locale = if (language.startsWith("bn")) Locale("bn", "BD") else Locale.US
        val availability = tts.isLanguageAvailable(locale)
        if (availability < TextToSpeech.LANG_AVAILABLE) {
            failure(
                if (language.startsWith("bn"))
                    "A Bengali voice is not installed. Open Android Settings › Text-to-speech output and install or select Bengali voice data."
                else "The selected Android text-to-speech voice is unavailable.",
                "voiceUnavailable",
            )
            return
        }
        requestFocus()
        tts.language = locale
        tts.setSpeechRate(rate)
        baseOffset = start.coerceIn(0, text.length)
        offset = baseOffset
        state = "loading"
        val params = Bundle().apply {
            putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "amar-$articleId")
        }
        tts.speak(text.substring(baseOffset), TextToSpeech.QUEUE_FLUSH, params, "amar-$articleId")
        startForeground(notificationId, notification())
    }

    private fun pauseSpeech() {
        if (state != "playing" && state != "loading") return
        tts.stop()
        state = "paused"
        emit("paused")
        updateSession()
    }

    private fun resumeSpeech() {
        if (state == "paused" || state == "completed") {
            if (state == "completed") offset = 0
            speakFrom(offset)
        }
    }

    private fun stopSpeech() {
        tts.stop()
        offset = 0
        state = "idle"
        emit("stopped")
        updateSession()
        abandonFocus()
        stopForeground(true)
        stopSelf()
    }

    private fun seekBySentence(direction: Int) {
        if (text.isEmpty()) return
        val boundaries = Regex("[.!?।]+(?:[\\\"”’)]*)?(?=\\s|$)").findAll(text)
            .map { it.range.last + 1 }.toList()
        val starts = listOf(0) + boundaries.map { end ->
            var value = end
            while (value < text.length && text[value].isWhitespace()) value++
            value
        }.filter { it < text.length }
        val current = max(0, starts.indexOfLast { it <= offset })
        offset = starts[(current + direction).coerceIn(0, starts.lastIndex)]
        if (state == "playing") speakFrom(offset) else emit("paused")
    }

    private fun requestFocus() {
        val listener = AudioManager.OnAudioFocusChangeListener { change ->
            when (change) {
                AudioManager.AUDIOFOCUS_LOSS,
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                    resumeAfterFocus = state == "playing"
                    pauseSpeech()
                }
                AudioManager.AUDIOFOCUS_GAIN -> if (resumeAfterFocus) {
                    resumeAfterFocus = false
                    resumeSpeech()
                }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build())
                .setOnAudioFocusChangeListener(listener)
                .build()
            audioManager.requestAudioFocus(focusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        }
    }

    private fun updateSession() {
        val playbackState = when (state) {
            "playing", "loading" -> PlaybackStateCompat.STATE_PLAYING
            "paused" -> PlaybackStateCompat.STATE_PAUSED
            "completed" -> PlaybackStateCompat.STATE_STOPPED
            else -> PlaybackStateCompat.STATE_NONE
        }
        mediaSession.setPlaybackState(PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_STOP or PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            )
            .setState(playbackState, offset.toLong(), rate)
            .build())
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification())
    }

    private fun notification(): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val playing = state == "playing" || state == "loading"
        val playAction = if (playing) "pause" else "resume"
        val playIcon = if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        return NotificationCompat.Builder(this, notificationChannel)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("Amar News · Listen")
            .setContentText(if (playing) "Reading article" else "Playback paused")
            .setContentIntent(contentIntent)
            .setOnlyAlertOnce(true)
            .setOngoing(playing)
            .addAction(android.R.drawable.ic_media_previous, "Back", commandIntent("seekBack"))
            .addAction(playIcon, if (playing) "Pause" else "Play", commandIntent(playAction))
            .addAction(android.R.drawable.ic_media_next, "Forward", commandIntent("seekForward"))
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", commandIntent("stop"))
            .setStyle(MediaStyle().setMediaSession(mediaSession.sessionToken).setShowActionsInCompactView(0, 1, 2))
            .build()
    }

    private fun commandIntent(command: String): PendingIntent {
        val intent = Intent(this, TtsPlaybackService::class.java).apply {
            action = "com.zubaxit.bdnewspaperhub.TTS_COMMAND"
            putExtra("command", when (command) {
                "seekBack" -> "nativeBack"
                "seekForward" -> "nativeForward"
                else -> command
            })
        }
        if (command == "seekBack") intent.putExtra("direction", -1)
        if (command == "seekForward") intent.putExtra("direction", 1)
        return PendingIntent.getService(
            this, command.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun emit(type: String, extra: Map<String, Any?> = emptyMap()) {
        val event = mutableMapOf<String, Any?>(
            "type" to type,
            "articleId" to articleId,
            "offset" to offset,
            "rate" to rate,
        )
        event.putAll(extra)
        eventSink?.invoke(event)
    }

    private fun failure(message: String, type: String = "error") {
        state = "error"
        emit(type, mapOf("message" to message))
        updateSession()
    }

    private fun instanceNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(NotificationChannel(
                notificationChannel,
                "Article playback",
                NotificationManager.IMPORTANCE_LOW,
            ))
        }
    }

    override fun onDestroy() {
        tts.stop()
        tts.shutdown()
        mediaSession.release()
        abandonFocus()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
