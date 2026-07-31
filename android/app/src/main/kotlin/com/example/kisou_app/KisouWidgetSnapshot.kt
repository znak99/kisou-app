package com.example.kisou_app

import android.content.Context
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeParseException

internal const val KISOU_WIDGET_SCHEMA_VERSION = 1
internal const val KISOU_WIDGET_KIND = "KisouDailyWidget"
internal const val KISOU_WIDGET_SNAPSHOT_FILE = "widget/widget_snapshot.json"

internal data class KisouWidgetReadySnapshot(
    val date: LocalDate,
    val validUntil: Instant,
    val feeling: String,
    val top: String,
    val bottom: String,
    val outer: String,
)

internal sealed interface KisouWidgetRenderState {
    val dateLabel: String

    data class Ready(
        override val dateLabel: String,
        val feelingLabel: String,
        val topLabel: String,
        val bottomLabel: String,
        val outerLabel: String,
    ) : KisouWidgetRenderState

    data class Placeholder(
        override val dateLabel: String,
    ) : KisouWidgetRenderState
}

internal class KisouWidgetSnapshotStore(context: Context) {
    private val target = File(context.noBackupFilesDir, KISOU_WIDGET_SNAPSHOT_FILE)
    private val pendingTarget = File(target.path + ".new")
    private val legacyBackupTarget = File(target.path + ".bak")
    private val atomicFile = AtomicFile(target)

    fun writeDurably(json: String) {
        val expectedBytes = json.toByteArray(Charsets.UTF_8)
        if (expectedBytes.size > MAX_SNAPSHOT_BYTES) {
            throw IllegalArgumentException("Widget snapshot is too large.")
        }
        target.parentFile?.let { directory ->
            if (!directory.exists() && !directory.mkdirs() && !directory.isDirectory) {
                throw IllegalStateException("Widget snapshot directory is unavailable.")
            }
        }
        val output = atomicFile.startWrite()
        try {
            output.write(expectedBytes)
            output.fd.sync()
        } catch (error: Throwable) {
            atomicFile.failWrite(output)
            throw error
        }
        // finishWrite can log some sync/rename/backup cleanup failures without
        // surfacing them to the caller on older Android versions. Never call
        // failWrite after this point because the stream may already be closed.
        atomicFile.finishWrite(output)
        requireNoAtomicResidue()
        val persistedBytes = try {
            if (!target.isFile || target.length() > MAX_SNAPSHOT_BYTES) {
                throw IllegalStateException("Widget snapshot commit is unavailable.")
            }
            atomicFile.readFully()
        } catch (error: Throwable) {
            throw IllegalStateException(
                "Widget snapshot commit could not be verified.",
                error,
            )
        }
        if (persistedBytes.size > MAX_SNAPSHOT_BYTES ||
            !persistedBytes.contentEquals(expectedBytes)
        ) {
            throw IllegalStateException("Widget snapshot commit mismatch.")
        }
        requireNoAtomicResidue()
    }

    fun read(): String? {
        if (!target.exists() &&
            !legacyBackupTarget.exists() &&
            !pendingTarget.exists()
        ) {
            return null
        }
        if (target.exists() &&
            (!target.isFile || target.length() > MAX_SNAPSHOT_BYTES)
        ) {
            throw IllegalStateException("Widget snapshot is invalid.")
        }
        val bytes = atomicFile.readFully()
        requireNoAtomicResidue()
        if (bytes.size > MAX_SNAPSHOT_BYTES) {
            throw IllegalStateException("Widget snapshot is too large.")
        }
        return bytes.toString(Charsets.UTF_8)
    }

    private fun requireNoAtomicResidue() {
        if (legacyBackupTarget.exists() || pendingTarget.exists()) {
            throw IllegalStateException("Widget snapshot commit residue remains.")
        }
    }

    private companion object {
        const val MAX_SNAPSHOT_BYTES = 8 * 1024
    }
}

internal object KisouWidgetSnapshotCodec {
    private val tokyo = ZoneId.of("Asia/Tokyo")
    private val datePattern = Regex("^\\d{4}-\\d{2}-\\d{2}$")
    private val expiryPattern =
        Regex(
            "^\\d{4}-\\d{2}-\\d{2}T(?:[01]\\d|2[0-3]):[0-5]\\d:[0-5]\\dZ$",
        )

    private val feelingLabels = mapOf(
        "VERY_HOT" to "とても暑く感じそうです",
        "HOT" to "暑く感じそうです",
        "WARM" to "暖かく感じそうです",
        "PERFECT" to "ちょうど良く感じそうです",
        "COOL" to "涼しく感じそうです",
        "COLD" to "寒く感じそうです",
        "VERY_COLD" to "とても寒く感じそうです",
    )
    private val topLabels = mapOf(
        "SLEEVELESS" to "タンクトップ",
        "SHORT_SLEEVE" to "半袖",
        "THIN_LONG" to "薄手の長袖",
        "LONG_SLEEVE" to "長袖",
        "THICK_LONG" to "厚手の長袖",
        "KNIT_SWEAT" to "ニット・スウェット",
    )
    private val bottomLabels = mapOf(
        "LONG_PANTS" to "長ズボン",
        "HALF_PANTS" to "半ズボン",
        "SHORT_PANTS" to "ショートパンツ",
        "SKIRT" to "スカート",
    )
    private val outerLabels = mapOf(
        "LIGHT_OUTER" to "薄手の羽織り",
        "CARDIGAN" to "カーディガン",
        "JACKET" to "ジャケット",
        "COAT" to "コート",
        "PADDING" to "ダウン",
    )

    const val SIGNED_OUT_ENVELOPE =
        "{\"schema_version\":1,\"state\":\"signed_out\"}"

    fun validateReadyEnvelope(raw: String) {
        parseReadyEnvelope(raw)
            ?: throw IllegalArgumentException("Invalid widget snapshot envelope.")
    }

    fun shouldDisableRoutes(raw: String?): Boolean {
        if (raw == null) return false
        if (raw == SIGNED_OUT_ENVELOPE) return true
        return parseReadyEnvelope(raw) == null
    }

    fun render(raw: String?, now: Instant = Instant.now()): KisouWidgetRenderState {
        val today = now.atZone(tokyo).toLocalDate()
        val dateLabel = "${today.monthValue}/${today.dayOfMonth}"
        val ready = raw?.let(::parseReadyEnvelope)
            ?: return KisouWidgetRenderState.Placeholder(dateLabel)
        if (ready.date != today || !now.isBefore(ready.validUntil)) {
            return KisouWidgetRenderState.Placeholder(dateLabel)
        }
        return KisouWidgetRenderState.Ready(
            dateLabel = "${ready.date.monthValue}/${ready.date.dayOfMonth}",
            feelingLabel = feelingLabels.getValue(ready.feeling),
            topLabel = topLabels.getValue(ready.top),
            bottomLabel = bottomLabels.getValue(ready.bottom),
            outerLabel = if (ready.outer == OUTER_NONE) {
                "アウターなし"
            } else {
                outerLabels.getValue(ready.outer)
            },
        )
    }

    private fun parseReadyEnvelope(raw: String): KisouWidgetReadySnapshot? {
        return try {
            val root = JSONObject(raw)
            if (!root.hasExactKeys(
                    "schema_version",
                    "state",
                    "date",
                    "valid_until",
                    "feeling",
                    "recommendation",
                ) ||
                root.opt("schema_version") as? Int != KISOU_WIDGET_SCHEMA_VERSION ||
                root.opt("state") as? String != "ready"
            ) {
                return null
            }
            val rawDate = root.opt("date") as? String ?: return null
            if (!datePattern.matches(rawDate)) return null
            val date = LocalDate.parse(rawDate)
            if (date.toString() != rawDate) return null

            val rawExpiry = root.opt("valid_until") as? String ?: return null
            if (!expiryPattern.matches(rawExpiry)) return null
            val validUntil = Instant.parse(rawExpiry)
            if (validUntil.toString() != rawExpiry) return null
            val expectedExpiry = date.plusDays(1).atStartOfDay(tokyo).toInstant()
            if (validUntil != expectedExpiry) return null

            val feeling = root.opt("feeling") as? String ?: return null
            if (!feelingLabels.containsKey(feeling)) return null
            val recommendation = root.opt("recommendation") as? JSONObject
                ?: return null
            if (!recommendation.hasExactKeys("top", "bottom", "outer")) return null
            val top = recommendation.opt("top") as? String ?: return null
            val bottom = recommendation.opt("bottom") as? String ?: return null
            val rawOuter = recommendation.opt("outer")
            val outer = when (rawOuter) {
                JSONObject.NULL -> OUTER_NONE
                is String -> rawOuter
                else -> return null
            }
            if (!topLabels.containsKey(top) ||
                !bottomLabels.containsKey(bottom) ||
                (outer != OUTER_NONE && !outerLabels.containsKey(outer))
            ) {
                return null
            }
            if (raw != canonicalReadyEnvelope(
                    date = rawDate,
                    validUntil = rawExpiry,
                    feeling = feeling,
                    top = top,
                    bottom = bottom,
                    outer = outer,
                )
            ) {
                return null
            }
            KisouWidgetReadySnapshot(
                date = date,
                validUntil = validUntil,
                feeling = feeling,
                top = top,
                bottom = bottom,
                outer = outer,
            )
        } catch (_: DateTimeParseException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun JSONObject.hasExactKeys(vararg expected: String): Boolean {
        val keys = keys().asSequence().toSet()
        return keys.size == expected.size && keys == expected.toSet()
    }

    private fun canonicalReadyEnvelope(
        date: String,
        validUntil: String,
        feeling: String,
        top: String,
        bottom: String,
        outer: String,
    ): String {
        val encodedOuter = if (outer == OUTER_NONE) "null" else "\"$outer\""
        return "{\"schema_version\":1,\"state\":\"ready\"," +
            "\"date\":\"$date\",\"valid_until\":\"$validUntil\"," +
            "\"feeling\":\"$feeling\",\"recommendation\":{" +
            "\"top\":\"$top\",\"bottom\":\"$bottom\"," +
            "\"outer\":$encodedOuter}}"
    }

    private const val OUTER_NONE = "__NONE__"
}
