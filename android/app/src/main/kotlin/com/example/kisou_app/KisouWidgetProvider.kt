package com.example.kisou_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.util.concurrent.Executors

class KisouWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        renderAsync(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        renderAsync(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    private fun renderAsync(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        val pendingResult = goAsync()
        widgetIoExecutor.execute {
            try {
                val state = loadState(context)
                ids.forEach { id -> updateWidget(context, manager, id, state) }
            } finally {
                pendingResult.finish()
            }
        }
    }

    companion object {
        private const val MEDIUM_MIN_WIDTH_DP = 250
        private const val HOME_REQUEST_CODE = 73011
        private val GARMENT_VIEW_IDS = intArrayOf(
            R.id.widget_outer,
            R.id.widget_top,
            R.id.widget_bottom,
        )
        internal val widgetIoExecutor = Executors.newSingleThreadExecutor()

        internal fun reloadAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, KisouWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return
            val state = loadState(context)
            ids.forEach { id -> updateWidget(context, manager, id, state) }
        }

        private fun loadState(context: Context): KisouWidgetRenderState {
            val raw = try {
                KisouWidgetSnapshotStore(context).read()
            } catch (_: Exception) {
                null
            }
            return KisouWidgetSnapshotCodec.render(raw)
        }

        private fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            state: KisouWidgetRenderState,
        ) {
            val minWidth = manager.getAppWidgetOptions(id)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val usesMediumLayout = minWidth >= MEDIUM_MIN_WIDTH_DP
            val layout = if (usesMediumLayout) {
                R.layout.kisou_widget_medium
            } else {
                R.layout.kisou_widget_small
            }
            val views = RemoteViews(context.packageName, layout)
            val usesCompactTextLayout =
                context.resources.configuration.fontScale >= 1.5f
            views.setViewVisibility(
                R.id.widget_title,
                if (usesCompactTextLayout) View.GONE else View.VISIBLE,
            )
            views.setTextViewText(R.id.widget_date, state.dateLabel)
            when (state) {
                is KisouWidgetRenderState.Ready -> {
                    views.setViewVisibility(
                        R.id.widget_status,
                        if (usesCompactTextLayout) View.GONE else View.VISIBLE,
                    )
                    setGarmentPresentation(
                        views = views,
                        visibility = View.VISIBLE,
                        maxLines = if (usesCompactTextLayout ||
                            !usesMediumLayout
                        ) {
                            1
                        } else {
                            3
                        },
                    )
                    views.setTextViewText(R.id.widget_status, state.feelingLabel)
                    views.setTextViewText(R.id.widget_outer, state.outerLabel)
                    views.setTextViewText(R.id.widget_top, state.topLabel)
                    views.setTextViewText(R.id.widget_bottom, state.bottomLabel)
                    views.setContentDescription(
                        R.id.widget_root,
                        context.getString(
                            R.string.widget_ready_description,
                            state.dateLabel,
                            state.feelingLabel,
                            state.outerLabel,
                            state.topLabel,
                            state.bottomLabel,
                        ),
                    )
                }
                is KisouWidgetRenderState.Placeholder -> {
                    views.setViewVisibility(R.id.widget_status, View.VISIBLE)
                    setGarmentPresentation(
                        views = views,
                        visibility = if (usesCompactTextLayout) {
                            View.GONE
                        } else {
                            View.VISIBLE
                        },
                        maxLines = if (usesMediumLayout) 3 else 1,
                    )
                    val placeholder = context.getString(R.string.widget_open_to_update)
                    views.setTextViewText(R.id.widget_status, placeholder)
                    views.setTextViewText(R.id.widget_outer, "—")
                    views.setTextViewText(R.id.widget_top, "—")
                    views.setTextViewText(R.id.widget_bottom, "—")
                    views.setContentDescription(
                        R.id.widget_root,
                        context.getString(
                            R.string.widget_placeholder_description,
                            state.dateLabel,
                        ),
                    )
                }
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                homePendingIntent(context),
            )
            manager.updateAppWidget(id, views)
        }

        private fun setGarmentPresentation(
            views: RemoteViews,
            visibility: Int,
            maxLines: Int,
        ) {
            for (garmentViewId in GARMENT_VIEW_IDS) {
                views.setViewVisibility(garmentViewId, visibility)
                views.setInt(garmentViewId, "setMaxLines", maxLines)
            }
        }

        private fun homePendingIntent(context: Context): PendingIntent {
            val scheme = if (context.packageName.endsWith(".dev")) {
                "kisou-dev"
            } else {
                "kisou"
            }
            val uri = Uri.Builder()
                .scheme(scheme)
                .authority("widget")
                .appendPath("home")
                .build()
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = uri
                `package` = context.packageName
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context,
                HOME_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
