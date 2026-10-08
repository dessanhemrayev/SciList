package com.dessanhemrayev.scilist

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.dessanhemrayev.scilist/update",
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"canRequestInstallPackages" -> {
					result.success(
						Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
							packageManager.canRequestPackageInstalls(),
					)
				}
				"openInstallSettings" -> {
					try {
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							startActivity(
								Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
									data = Uri.parse("package:$packageName")
								},
							)
						}
						result.success(null)
					} catch (error: Exception) {
						result.error("settings_unavailable", error.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
