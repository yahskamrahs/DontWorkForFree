package com.example.dontworkforfree

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.os.SystemClock
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity required by local_auth for biometric dialogs
class MainActivity : FlutterFragmentActivity() {

    private val batteryChannel = "com.example.dontworkforfree/battery"
    private val notificationChannel = "com.example.dontworkforfree/notifications"
    private var methodChannel: MethodChannel? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, batteryChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannel)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showActiveShiftNotification" -> {
                    val isOvertime = call.argument<Boolean>("isOvertime") ?: false
                    val anchorEpochMillis = call.argument<Any>("anchorEpochMillis")?.toString()?.toLong() ?: System.currentTimeMillis()
                    val progressPercent = call.argument<Any>("progressPercent")?.toString()?.toInt() ?: 0
                    val isOnBreak = call.argument<Boolean>("isOnBreak") ?: false
                    val breakStartEpochMillis = call.argument<Any>("breakStartEpochMillis")?.toString()?.toLong() ?: 0L
                    CustomNotificationManager.showActiveShiftNotification(this, isOvertime, anchorEpochMillis, progressPercent, isOnBreak, breakStartEpochMillis)
                    result.success(null)
                }
                "showJokeNotification" -> {
                    val title = call.argument<String>("title") ?: "Joke"
                    val joke = call.argument<String>("joke") ?: ""
                    CustomNotificationManager.showJokeNotification(this, title, joke)
                    result.success(null)
                }
                "cancelActiveShiftNotification" -> {
                    CustomNotificationManager.cancelActiveShiftNotification(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val action = intent.action
        if (action == "ACTION_PAUSE" || action == "ACTION_CLOCK_OUT") {
            methodChannel?.invokeMethod("onNotificationAction", action)
        }
    }
}
