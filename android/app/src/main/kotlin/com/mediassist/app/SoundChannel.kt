package com.mediassist.app

import android.app.Activity
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The system ringtone picker, and a preview player for the sound-picker UI.
 *
 * Both live natively because both need a `Context` that Dart does not have:
 * `RingtoneManager`'s picker is an Activity result, and playing a
 * `content://` ringtone needs `MediaPlayer.setDataSource(context, uri)` — the
 * string overload the `alarm` plugin uses cannot open one. That asymmetry is
 * exactly why a picked sound is copied into the app's own storage before it is
 * ever attached to an alarm; see `AlarmSound` on the Dart side.
 */
class SoundChannel(private val activity: Activity) {

    private var pendingPickerResult: MethodChannel.Result? = null
    private var previewPlayer: MediaPlayer? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickRingtone" -> pickRingtone(call, result)
            "copyUri" -> copyUri(call, result)
            "preview" -> preview(call, result)
            "stopPreview" -> {
                stopPreview()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Releases anything still playing — call from the Activity's onDestroy. */
    fun dispose() {
        stopPreview()
        // A pending picker can never be answered once the Activity is gone;
        // leaving the Dart future hanging would freeze the picker sheet.
        pendingPickerResult?.success(null)
        pendingPickerResult = null
    }

    // ─── Ringtone picker ─────────────────────────────────────────────────────

    private fun pickRingtone(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("busy", "A ringtone picker is already open", null)
            return
        }

        // Alarms first, but ringtones and notification tones are offered too:
        // plenty of people want a specific ringtone as their adhan, and the
        // alarm-only picker hides those entirely.
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALL)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE,
                call.argument<String>("title") ?: "Select sound")
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
            call.argument<String>("currentUri")?.let {
                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(it))
            }
        }

        try {
            pendingPickerResult = result
            activity.startActivityForResult(intent, REQUEST_PICK_RINGTONE)
        } catch (e: Exception) {
            pendingPickerResult = null
            Log.e(TAG, "No ringtone picker available", e)
            result.error("unavailable", "No ringtone picker on this device", null)
        }
    }

    /**
     * Returns true when this consumed the result.
     *
     * The answer is the ringtone's `content://` URI plus its title — the Dart
     * side then asks for the bytes and copies them somewhere durable.
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_RINGTONE) return false

        val result = pendingPickerResult ?: return true
        pendingPickerResult = null

        if (resultCode != Activity.RESULT_OK) {
            // Cancelled. Not an error — null tells Dart to leave the choice
            // alone rather than to show a failure.
            result.success(null)
            return true
        }

        val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        if (uri == null) {
            result.success(null)
            return true
        }

        val title = try {
            RingtoneManager.getRingtone(activity, uri)?.getTitle(activity)
        } catch (e: Exception) {
            Log.w(TAG, "Could not read ringtone title", e)
            null
        }

        result.success(mapOf("uri" to uri.toString(), "title" to (title ?: "")))
        return true
    }

    // ─── Copying a picked sound into the app's own storage ───────────────────

    /**
     * Streams the audio behind a `content://` URI into the app's storage.
     *
     * A ringtone URI is only readable through a `ContentResolver`, and only
     * while this process holds the grant — neither of which is true of the
     * broadcast receiver that re-arms alarms days later. Copying once, here, is
     * what makes the sound survive.
     *
     * The extension comes from the resolver's MIME type rather than the URI,
     * which for a media-store ringtone carries no file name at all.
     */
    private fun copyUri(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        val directory = call.argument<String>("directory")
        val baseName = call.argument<String>("baseName")
        val maxBytes = (call.argument<Int>("maxBytes") ?: DEFAULT_MAX_BYTES).toLong()

        if (uriString == null || directory == null || baseName == null) {
            result.error("bad_args", "uri, directory and baseName are required", null)
            return
        }

        try {
            val uri = Uri.parse(uriString)
            val resolver = activity.contentResolver
            val extension = extensionFor(resolver.getType(uri))
            val destination = java.io.File(directory, "$baseName.$extension")
            destination.parentFile?.mkdirs()

            var copied = 0L
            resolver.openInputStream(uri).use { input ->
                if (input == null) {
                    result.error("unreadable", "Could not open $uriString", null)
                    return
                }
                destination.outputStream().use { output ->
                    val buffer = ByteArray(8 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        copied += read
                        if (copied > maxBytes) {
                            output.flush()
                            destination.delete()
                            result.error("too_large", "Sound exceeds $maxBytes bytes", null)
                            return
                        }
                        output.write(buffer, 0, read)
                    }
                }
            }

            if (copied == 0L) {
                destination.delete()
                result.error("unreadable", "Sound was empty", null)
                return
            }

            result.success(mapOf("path" to destination.absolutePath, "bytes" to copied))
        } catch (e: SecurityException) {
            Log.e(TAG, "No permission to read $uriString", e)
            result.error("permission_denied", e.message, null)
        } catch (e: Exception) {
            Log.e(TAG, "Copy failed for $uriString", e)
            result.error("copy_failed", e.message, null)
        }
    }

    private fun extensionFor(mimeType: String?): String = when (mimeType) {
        "audio/mpeg", "audio/mp3" -> "mp3"
        "audio/ogg", "application/ogg" -> "ogg"
        "audio/wav", "audio/x-wav" -> "wav"
        "audio/mp4", "audio/m4a", "audio/x-m4a" -> "m4a"
        "audio/aac" -> "aac"
        "audio/flac", "audio/x-flac" -> "flac"
        "audio/opus" -> "opus"
        "audio/midi", "audio/x-midi" -> "mid"
        // MediaPlayer sniffs the container rather than trusting the name, so an
        // unknown type is still playable — it just gets a generic extension.
        else -> "audio"
    }

    // ─── Preview ─────────────────────────────────────────────────────────────

    /**
     * Plays a sound once so the user can hear what they are choosing.
     *
     * Accepts the same three shapes the alarm plugin does — a bundled asset, a
     * path relative to the app documents directory, an absolute path — plus
     * `content://` URIs, which only this side can open, and null for the
     * device's default alarm tone.
     */
    private fun preview(call: MethodCall, result: MethodChannel.Result) {
        stopPreview()

        val path = call.argument<String>("path")
        try {
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )

            when {
                path == null -> {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    if (uri == null) {
                        player.release()
                        result.error("unavailable", "No default alarm sound", null)
                        return
                    }
                    player.setDataSource(activity, uri)
                }

                path.startsWith("content://") || path.startsWith("file://") ->
                    player.setDataSource(activity, Uri.parse(path))

                path.startsWith("assets/") -> {
                    val descriptor = activity.assets.openFd("flutter_assets/$path")
                    player.setDataSource(
                        descriptor.fileDescriptor,
                        descriptor.startOffset,
                        descriptor.length,
                    )
                }

                path.startsWith("/") -> player.setDataSource(path)

                else -> {
                    // Relative to the app documents directory, the same way the
                    // alarm plugin resolves it.
                    val base = activity.filesDir.parent?.plus("/app_flutter/")
                    player.setDataSource(base + path)
                }
            }

            player.setOnCompletionListener { stopPreview() }
            player.setOnErrorListener { _, _, _ ->
                stopPreview()
                true
            }
            player.prepare()
            player.start()
            previewPlayer = player
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Preview failed for $path", e)
            stopPreview()
            result.error("preview_failed", e.message, null)
        }
    }

    private fun stopPreview() {
        previewPlayer?.let { player ->
            try {
                if (player.isPlaying) player.stop()
            } catch (e: IllegalStateException) {
                Log.w(TAG, "Preview player already stopped", e)
            }
            player.release()
        }
        previewPlayer = null
    }

    companion object {
        private const val TAG = "SoundChannel"
        const val CHANNEL = "com.mediassist.app/sound"
        private const val REQUEST_PICK_RINGTONE = 19782
        private const val DEFAULT_MAX_BYTES = 10 * 1024 * 1024
    }
}
