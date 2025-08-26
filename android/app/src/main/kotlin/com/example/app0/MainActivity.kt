package com.example.app0

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import android.util.Base64
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream

class MainActivity : FlutterActivity() {
	private val CHANNEL = "com.agrinas.deteksi_sawit/media"

	override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
				when (call.method) {
					"saveCsvToDownloads" -> {
						val filename = call.argument<String>("filename")
						val base64 = call.argument<String>("base64")
						if (filename == null || base64 == null) {
							result.error("bad_args", "filename or base64 missing", null)
							return@setMethodCallHandler
						}
						try {
							val saved = saveCsvToDownloads(filename, base64)
							if (saved) result.success(true) else result.error("save_failed", "failed to save file", null)
						} catch (e: Exception) {
							result.error("exception", e.message, null)
						}
					}
					"saveImageToGallery" -> {
						val filename = call.argument<String>("filename")
						val base64 = call.argument<String>("base64")
						val mime = call.argument<String>("mimeType") ?: "image/png"
						if (filename == null || base64 == null) {
							result.error("bad_args", "filename or base64 missing", null)
							return@setMethodCallHandler
						}
						try {
							val uriStr = saveImageToGallery(filename, base64, mime)
							if (uriStr != null) result.success(uriStr) else result.error("save_failed", "failed to save image", null)
						} catch (e: Exception) {
							result.error("exception", e.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun saveCsvToDownloads(filename: String, base64: String): Boolean {
		val bytes = Base64.decode(base64, Base64.DEFAULT)
		val resolver = contentResolver

		val contentValues = ContentValues().apply {
			put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
			put(MediaStore.MediaColumns.MIME_TYPE, "text/csv")
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/")
			}
		}

		val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
			?: return false

		var out: OutputStream? = null
		return try {
			out = resolver.openOutputStream(uri)
			out?.write(bytes)
			out?.flush()
			true
		} catch (e: Exception) {
			e.printStackTrace()
			false
		} finally {
			out?.close()
		}
	}

	private fun saveImageToGallery(filename: String, base64: String, mimeType: String): String? {
		val bytes = Base64.decode(base64, Base64.DEFAULT)
		val resolver = contentResolver

		val contentValues = ContentValues().apply {
			put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
			put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/DeteksiSawit")
			}
		}

		val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
			?: return null

		var out: OutputStream? = null
		return try {
			out = resolver.openOutputStream(uri)
			out?.write(bytes)
			out?.flush()
			uri.toString()
		} catch (e: Exception) {
			e.printStackTrace()
			null
		} finally {
			out?.close()
		}
	}
}
