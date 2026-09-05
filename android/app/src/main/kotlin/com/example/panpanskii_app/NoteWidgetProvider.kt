package com.example.panpanskii_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Home-screen widget that shows the partner's latest hand-drawn note.
 *
 * Metadata (username, caption, and a Supabase signed URL for the PNG) is
 * written from Dart via `HomeWidget.saveWidgetData` (see
 * `WidgetNoteHomeWidgetService`). On every update the widget itself downloads
 * the PNG over WiFi/mobile data — no Flutter code has to be running. The
 * downloaded image is cached so the last note still shows when offline.
 */
class NoteWidgetProvider : HomeWidgetProvider() {

    private companion object {
        const val KEY_IMAGE_URL = "widget_note_image_url"
        const val KEY_CACHED_URL = "widget_note_cached_url"
        const val CONNECT_TIMEOUT_MS = 8000
        const val READ_TIMEOUT_MS = 8000
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // goAsync keeps this broadcast receiver alive while we fetch over the
        // network on a worker thread.
        val pendingResult = goAsync()
        thread(name = "note-widget-download") {
            try {
                appWidgetIds.forEach { widgetId ->
                    render(context, appWidgetManager, widgetId, widgetData)
                }
            } catch (error: Exception) {
                android.util.Log.e("NoteWidget", "Widget update failed", error)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
    ) {
        // Paint the green spinner right away so the widget never looks frozen
        // while the PNG is being pulled over WiFi/mobile data.
        appWidgetManager.updateAppWidget(widgetId, loadingViews(context))

        val imageUrl = widgetData.getString(KEY_IMAGE_URL, null)
        val cacheFile = File(context.filesDir, "widget_note_cache/latest.png")
        val bitmap = resolveBitmap(imageUrl, cacheFile, widgetData)

        val views = RemoteViews(context.packageName, R.layout.widget_note_layout).apply {
            val username = widgetData.getString("widget_note_username", null)
            val caption = widgetData.getString("widget_note_caption", null)

            setViewVisibility(R.id.widget_loader, View.GONE)

            setTextViewText(
                R.id.widget_note_author,
                if (username.isNullOrBlank()) {
                    context.getString(R.string.widget_note_empty_author)
                } else {
                    context.getString(R.string.widget_note_from, username)
                },
            )
            setTextViewText(
                R.id.widget_note_caption,
                if (caption.isNullOrBlank()) "" else caption,
            )

            if (bitmap != null) {
                setImageViewBitmap(R.id.widget_note_image, bitmap)
                setViewVisibility(R.id.widget_note_image, View.VISIBLE)
                setViewVisibility(R.id.widget_note_empty, View.GONE)
            } else {
                setViewVisibility(R.id.widget_note_image, View.GONE)
                setViewVisibility(R.id.widget_note_empty, View.VISIBLE)
            }
        }
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    /** The spinner-only state shown while the note image is downloading. */
    private fun loadingViews(context: Context): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_note_layout).apply {
            setViewVisibility(R.id.widget_loader, View.VISIBLE)
            setViewVisibility(R.id.widget_note_image, View.GONE)
            setViewVisibility(R.id.widget_note_empty, View.GONE)
        }

    /**
     * Downloads the PNG when the URL is new (or the cache is gone), then falls
     * back to the cached copy whenever the network is unavailable or the signed
     * URL has expired. Returns null when there is nothing to show.
     */
    private fun resolveBitmap(
        imageUrl: String?,
        cacheFile: File,
        widgetData: SharedPreferences,
    ): android.graphics.Bitmap? {
        if (imageUrl.isNullOrBlank()) {
            return cacheFile.takeIf { it.exists() }
                ?.let { BitmapFactory.decodeFile(it.absolutePath) }
        }

        val needsDownload = widgetData.getString(KEY_CACHED_URL, null) != imageUrl ||
            !cacheFile.exists()

        if (needsDownload) {
            val fresh = downloadBitmap(imageUrl)
            if (fresh != null) {
                try {
                    cacheFile.parentFile?.mkdirs()
                    cacheFile.writeBytes(fresh)
                    widgetData.edit().putString(KEY_CACHED_URL, imageUrl).apply()
                    return BitmapFactory.decodeFile(cacheFile.absolutePath)
                } catch (_: Exception) {
                    // Cache write failed; keep whatever we can still show.
                }
            }
        }

        if (cacheFile.exists()) {
            val cached = BitmapFactory.decodeFile(cacheFile.absolutePath)
            if (cached != null) return cached
        }

        return downloadBitmap(imageUrl)?.let { bytes ->
            try {
                cacheFile.parentFile?.mkdirs()
                cacheFile.writeBytes(bytes)
                BitmapFactory.decodeFile(cacheFile.absolutePath)
            } catch (_: Exception) {
                null
            }
        }
    }

    /** Fetches PNG bytes over the network; null on any failure. */
    private fun downloadBitmap(url: String): ByteArray? {
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.setRequestProperty("Cache-Control", "no-cache")
            try {
                if (connection.responseCode !in 200..299) return null
                connection.inputStream.use { it.readBytes() }
            } finally {
                connection.disconnect()
            }
        } catch (_: Exception) {
            null
        }
    }
}
