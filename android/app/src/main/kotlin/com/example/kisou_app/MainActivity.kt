package com.example.kisou_app

import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "jp.kisou/push",
        ).setMethodCallHandler { call, result ->
            if (call.method != "clearDisplayedPushNotifications") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.activeNotifications
                .filter { notification ->
                    notification.tag == DAILY_PUSH_TAG ||
                        (
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                notification.notification.channelId == DAILY_PUSH_CHANNEL
                        )
                }
                .forEach { notification ->
                    notificationManager.cancel(notification.tag, notification.id)
                }
            result.success(null)
        }
    }

    private companion object {
        const val DAILY_PUSH_CHANNEL = "push_daily_v1"
        const val DAILY_PUSH_TAG = "kisou_daily_push_v1"
    }
}
