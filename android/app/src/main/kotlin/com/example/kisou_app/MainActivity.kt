package com.example.kisou_app

import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetHomeRoute = false
    private var widgetRoutesDisabled = true
    private var widgetRouteLeaseResolved = false
    private var widgetRouteEpoch = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        val initialWidgetHomeIntent = isAllowedWidgetHomeIntent(intent)
        widgetRoutesDisabled = true
        widgetRouteLeaseResolved = false
        pendingWidgetHomeRoute = initialWidgetHomeIntent
        if (initialWidgetHomeIntent) {
            // The custom bridge owns this URI. A cached signed-out fence must
            // remove it before FlutterActivity can inspect the launch intent.
            intent?.data = null
        }
        super.onCreate(savedInstanceState)
        hydrateWidgetRouteLease()
    }

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
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "jp.kisou/widget",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "writeSnapshot" -> {
                        val raw = call.arguments as? String
                        if (raw == null) {
                            result.error(
                                "INVALID_WIDGET_SNAPSHOT",
                                "Widget snapshot must be JSON text.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        // Same-account publishes do not supersede cold-start
                        // lease hydration. Only account close advances the
                        // epoch and fences an older ready completion.
                        val operationEpoch = widgetRouteEpoch
                        runWidgetIo(
                            result = result,
                            onSuccess = {
                                if (operationEpoch == widgetRouteEpoch) {
                                    widgetRouteLeaseResolved = true
                                    widgetRoutesDisabled = false
                                    notifyPendingWidgetHomeRoute()
                                }
                            },
                        ) {
                            KisouWidgetSnapshotCodec.validateReadyEnvelope(raw)
                            KisouWidgetSnapshotStore(applicationContext)
                                .writeDurably(raw)
                            KisouWidgetProvider.reloadAll(applicationContext)
                        }
                    }
                    "closeAccount" -> {
                        val routesWereDisabled = widgetRoutesDisabled
                        val leaseWasResolved = widgetRouteLeaseResolved
                        val operationEpoch = ++widgetRouteEpoch
                        widgetRouteLeaseResolved = true
                        widgetRoutesDisabled = true
                        pendingWidgetHomeRoute = false
                        intent?.data = null
                        runWidgetIo(
                            result = result,
                            onSuccess = {
                                // A tap can race with disk I/O and widget
                                // reload. Make route clearing the final UI
                                // mutation before acknowledging close. The
                                // route stays disabled until a ready write.
                                if (operationEpoch == widgetRouteEpoch) {
                                    pendingWidgetHomeRoute = false
                                    intent?.data = null
                                    widgetRouteLeaseResolved = true
                                    widgetRoutesDisabled = true
                                }
                            },
                            onFailure = {
                                if (operationEpoch == widgetRouteEpoch) {
                                    pendingWidgetHomeRoute = false
                                    intent?.data = null
                                    widgetRouteLeaseResolved = leaseWasResolved
                                    widgetRoutesDisabled = routesWereDisabled
                                    if (!leaseWasResolved) {
                                        hydrateWidgetRouteLease()
                                    }
                                }
                            },
                        ) {
                            KisouWidgetSnapshotStore(applicationContext)
                                .writeDurably(
                                    KisouWidgetSnapshotCodec.SIGNED_OUT_ENVELOPE,
                            )
                            KisouWidgetProvider.reloadAll(applicationContext)
                        }
                    }
                    "consumeInitialWidgetRoute" -> {
                        if (!widgetRouteLeaseResolved) {
                            // A cold/warm tap that arrives before the durable
                            // lease is known remains pending. Hydration will
                            // issue a callback after it resolves as enabled.
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val pending =
                            pendingWidgetHomeRoute && !widgetRoutesDisabled
                        pendingWidgetHomeRoute = false
                        intent?.data = null
                        result.success(pending)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        val isWidgetHomeIntent = isAllowedWidgetHomeIntent(intent)
        if (isWidgetHomeIntent && !widgetRouteLeaseResolved) {
            // Keep the candidate while startup storage hydration decides
            // whether this account's route lease is still valid.
            pendingWidgetHomeRoute = true
            intent.data = null
            this.intent?.data = null
            return
        }
        if (isWidgetHomeIntent && widgetRoutesDisabled) {
            // Do not let Flutter's deep-link plugin observe an old-account
            // widget route while the signed-out boundary is being written.
            pendingWidgetHomeRoute = false
            this.intent?.data = null
            return
        }
        super.onNewIntent(intent)
        setIntent(intent)
        if (!isWidgetHomeIntent) return
        pendingWidgetHomeRoute = true
        widgetChannel?.invokeMethod("widgetHomeRoute", null)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        widgetChannel?.setMethodCallHandler(null)
        widgetChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun runWidgetIo(
        result: MethodChannel.Result,
        onSuccess: () -> Unit = {},
        onFailure: () -> Unit = {},
        operation: () -> Unit,
    ) {
        KisouWidgetProvider.widgetIoExecutor.execute {
            try {
                operation()
                runOnUiThread {
                    onSuccess()
                    result.success(null)
                }
            } catch (_: Exception) {
                runOnUiThread {
                    onFailure()
                    result.error(
                        "WIDGET_STORAGE_FAILED",
                        "Could not update the widget snapshot.",
                        null,
                    )
                }
            }
        }
    }

    private fun hydrateWidgetRouteLease() {
        val hydrationEpoch = widgetRouteEpoch
        KisouWidgetProvider.widgetIoExecutor.execute {
            val resolvedRoutesDisabled = try {
                KisouWidgetSnapshotCodec.shouldDisableRoutes(
                    KisouWidgetSnapshotStore(applicationContext).read(),
                )
            } catch (_: Exception) {
                // A protected or unreadable route boundary is fail-closed.
                true
            }
            val routesDisabled = resolvedRoutesDisabled
            runOnUiThread {
                if (hydrationEpoch != widgetRouteEpoch) return@runOnUiThread
                widgetRouteLeaseResolved = true
                widgetRoutesDisabled = routesDisabled
                if (routesDisabled) {
                    pendingWidgetHomeRoute = false
                    intent?.data = null
                } else {
                    notifyPendingWidgetHomeRoute()
                }
            }
        }
    }

    private fun notifyPendingWidgetHomeRoute() {
        if (widgetRouteLeaseResolved &&
            !widgetRoutesDisabled &&
            pendingWidgetHomeRoute
        ) {
            widgetChannel?.invokeMethod("widgetHomeRoute", null)
        }
    }

    private fun isAllowedWidgetHomeIntent(candidate: Intent?): Boolean {
        if (candidate?.action != Intent.ACTION_VIEW) return false
        val uri = candidate.data ?: return false
        val expectedScheme = if (packageName.endsWith(".dev")) {
            "kisou-dev"
        } else {
            "kisou"
        }
        return uri.scheme == expectedScheme &&
            uri.host == "widget" &&
            uri.path == "/home" &&
            uri.userInfo == null &&
            uri.port == -1 &&
            uri.query == null &&
            uri.fragment == null
    }

    private companion object {
        const val DAILY_PUSH_CHANNEL = "push_daily_v1"
        const val DAILY_PUSH_TAG = "kisou_daily_push_v1"
    }
}
