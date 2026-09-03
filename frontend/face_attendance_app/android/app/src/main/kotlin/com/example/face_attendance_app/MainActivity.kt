package com.example.face_attendance_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "face_attendance/downloads")
			.setMethodCallHandler { call, result ->
				if (call.method != "saveFileToDownloads") {
					result.notImplemented()
					return@setMethodCallHandler
				}

				val fileName = call.argument<String>("fileName")
				val mimeType = call.argument<String>("mimeType")
				val bytes = call.argument<ByteArray>("bytes")
				if (fileName == null || mimeType == null || bytes == null) {
					result.error("INVALID_ARGUMENTS", "File name, MIME type, and bytes are required.", null)
					return@setMethodCallHandler
				}

				try {
					val savedPath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
						val values = ContentValues().apply {
							put(MediaStore.Downloads.DISPLAY_NAME, fileName)
							put(MediaStore.Downloads.MIME_TYPE, mimeType)
							put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
							put(MediaStore.Downloads.IS_PENDING, 1)
						}
						val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
							?: throw IllegalStateException("Unable to create download file")
						contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
							?: throw IllegalStateException("Unable to write download file")
						values.clear()
						values.put(MediaStore.Downloads.IS_PENDING, 0)
						contentResolver.update(uri, values, null, null)
						uri.toString()
					} else {
						val directory = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
						directory.mkdirs()
						val file = File(directory, fileName)
						file.writeBytes(bytes)
						file.absolutePath
					}
					result.success(savedPath)
				} catch (error: Exception) {
					result.error("DOWNLOAD_FAILED", error.message, null)
				}
			}
	}
}
