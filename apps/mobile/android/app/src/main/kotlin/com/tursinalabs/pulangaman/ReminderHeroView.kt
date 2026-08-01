package com.tursinalabs.pulangaman

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Soft hero illustration for reminder full-screen — mood from title keywords
 * (tidur / belajar / emp / default), drawn without bitmap assets.
 *
 * Accent colors come from [momentAccent] so Visual Refresh templates can swap
 * gold / vivid green / sage / terracotta without hardcoding per draw path.
 */
class ReminderHeroView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    enum class Mood { SLEEP, STUDY, EMP, DEFAULT, STREAK_STAR, STREAK_TROPHY, STREAK_MEDAL }

    var mood: Mood = Mood.DEFAULT
        set(value) {
            field = value
            invalidate()
        }

    /** Moment accent fill (illustration + rings). */
    var momentAccent: Int = 0xFFFFC857.toInt()
        set(value) {
            field = value
            invalidate()
        }

    /** Soft circular backdrop behind the glyph. */
    var illustrationBg: Int = 0xFF2C4C41.toInt()
        set(value) {
            field = value
            invalidate()
        }

    /** Screen background used to cut crescent / pin hole. */
    var canvasBg: Int = 0xFF16362C.toInt()
        set(value) {
            field = value
            invalidate()
        }

    var visualRefresh: Boolean = false
        set(value) {
            field = value
            invalidate()
        }

    private val disc = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val accent = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val soft = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val star = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val path = Path()

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f || h <= 0f) return
        val cx = w / 2f
        val cy = h / 2f
        val r = min(w, h) * 0.38f

        when (mood) {
            Mood.SLEEP -> drawSleep(canvas, cx, cy, r)
            Mood.STUDY -> drawStudy(canvas, cx, cy, r)
            Mood.EMP -> drawEmp(canvas, cx, cy, r)
            Mood.STREAK_STAR -> drawStreakStar(canvas, cx, cy, r)
            Mood.STREAK_TROPHY -> drawStreakTrophy(canvas, cx, cy, r, withRibbon = false)
            Mood.STREAK_MEDAL -> drawStreakTrophy(canvas, cx, cy, r, withRibbon = true)
            Mood.DEFAULT -> drawDefault(canvas, cx, cy, r)
        }
    }

    private fun drawSleep(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        soft.color = if (visualRefresh) illustrationBg else 0x33FFFFFF
        soft.alpha = if (visualRefresh) 220 else 51
        canvas.drawCircle(cx, cy, r * 1.15f, soft)

        accent.color = momentAccent
        canvas.drawCircle(cx - r * 0.15f, cy - r * 0.05f, r * 0.72f, accent)

        disc.color = canvasBg
        canvas.drawCircle(cx + r * 0.22f, cy - r * 0.18f, r * 0.58f, disc)

        star.color = 0xFFFFF4C8.toInt()
        drawStar(canvas, cx + r * 0.72f, cy - r * 0.55f, r * 0.08f)
        drawStar(canvas, cx - r * 0.78f, cy + r * 0.15f, r * 0.055f)
        drawStar(canvas, cx + r * 0.55f, cy + r * 0.62f, r * 0.045f)

        soft.color = 0x55FFFFFF
        canvas.drawOval(
            RectF(cx - r * 0.55f, cy + r * 0.55f, cx + r * 0.55f, cy + r * 0.95f),
            soft,
        )
    }

    private fun drawStudy(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        soft.color = if (visualRefresh) illustrationBg else 0x28FFFFFF
        soft.alpha = if (visualRefresh) 220 else 40
        canvas.drawCircle(cx, cy, r * 1.1f, soft)

        accent.color = momentAccent
        path.reset()
        path.moveTo(cx - r * 0.7f, cy + r * 0.15f)
        path.quadTo(cx - r * 0.35f, cy - r * 0.35f, cx, cy + r * 0.05f)
        path.quadTo(cx + r * 0.35f, cy - r * 0.35f, cx + r * 0.7f, cy + r * 0.15f)
        path.quadTo(cx + r * 0.2f, cy + r * 0.55f, cx, cy + r * 0.45f)
        path.quadTo(cx - r * 0.2f, cy + r * 0.55f, cx - r * 0.7f, cy + r * 0.15f)
        path.close()
        canvas.drawPath(path, accent)

        val spine = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = canvasBg
            style = Paint.Style.STROKE
            strokeWidth = r * 0.04f
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawLine(cx, cy - r * 0.05f, cx, cy + r * 0.45f, spine)

        soft.color = 0x55FFFFFF
        canvas.drawOval(
            RectF(cx - r * 0.5f, cy + r * 0.58f, cx + r * 0.5f, cy + r * 0.92f),
            soft,
        )
    }

    private fun drawEmp(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        soft.color = illustrationBg
        soft.alpha = 220
        canvas.drawCircle(cx, cy, r * 1.15f, soft)

        stroke.color = 0x38B9CFC5
        stroke.strokeWidth = 2f
        canvas.drawCircle(cx, cy, r * 0.95f, stroke)
        canvas.drawCircle(cx, cy, r * 0.72f, stroke)
        canvas.drawCircle(cx, cy, r * 0.48f, stroke)

        soft.color = 0x55000000
        canvas.drawOval(
            RectF(cx - r * 0.45f, cy + r * 0.48f, cx + r * 0.45f, cy + r * 0.78f),
            soft,
        )

        accent.color = momentAccent
        path.reset()
        path.moveTo(cx, cy - r * 0.55f)
        path.cubicTo(
            cx + r * 0.42f, cy - r * 0.55f,
            cx + r * 0.42f, cy + r * 0.05f,
            cx, cy + r * 0.42f,
        )
        path.cubicTo(
            cx - r * 0.42f, cy + r * 0.05f,
            cx - r * 0.42f, cy - r * 0.55f,
            cx, cy - r * 0.55f,
        )
        path.close()
        canvas.drawPath(path, accent)

        disc.color = canvasBg
        canvas.drawCircle(cx, cy - r * 0.18f, r * 0.14f, disc)
    }

    private fun drawDefault(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        soft.color = if (visualRefresh) illustrationBg else 0x28FFFFFF
        soft.alpha = if (visualRefresh) 220 else 40
        canvas.drawCircle(cx, cy, r * 1.1f, soft)

        // Bell body
        accent.color = momentAccent
        canvas.drawCircle(cx, cy - r * 0.08f, r * 0.38f, accent)
        canvas.drawRoundRect(
            RectF(cx - r * 0.42f, cy + r * 0.12f, cx + r * 0.42f, cy + r * 0.32f),
            r * 0.08f,
            r * 0.08f,
            accent,
        )
        // Clapper
        canvas.drawCircle(cx, cy + r * 0.42f, r * 0.1f, accent)
        // Handle
        stroke.color = momentAccent
        stroke.strokeWidth = r * 0.07f
        stroke.strokeCap = Paint.Cap.ROUND
        canvas.drawArc(
            RectF(cx - r * 0.18f, cy - r * 0.55f, cx + r * 0.18f, cy - r * 0.2f),
            200f,
            140f,
            false,
            stroke,
        )

        soft.color = 0x55FFFFFF
        canvas.drawOval(
            RectF(cx - r * 0.5f, cy + r * 0.58f, cx + r * 0.5f, cy + r * 0.92f),
            soft,
        )
    }

    private fun drawStreakStar(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        soft.color = if (visualRefresh) illustrationBg else 0x28FFFFFF
        soft.alpha = if (visualRefresh) 220 else 40
        canvas.drawCircle(cx, cy, r * 1.12f, soft)

        star.color = momentAccent
        drawStar(canvas, cx, cy, r * 0.42f)

        star.color = 0xFFFFF4C8.toInt()
        drawStar(canvas, cx + r * 0.72f, cy - r * 0.55f, r * 0.1f)
        drawStar(canvas, cx - r * 0.7f, cy - r * 0.2f, r * 0.07f)
        drawStar(canvas, cx + r * 0.55f, cy + r * 0.55f, r * 0.06f)
        drawStar(canvas, cx - r * 0.5f, cy + r * 0.6f, r * 0.05f)
    }

    private fun drawStreakTrophy(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        r: Float,
        withRibbon: Boolean,
    ) {
        soft.color = if (visualRefresh) illustrationBg else 0x28FFFFFF
        soft.alpha = if (visualRefresh) 220 else 40
        canvas.drawCircle(cx, cy, r * 1.12f, soft)

        accent.color = momentAccent
        // Cup body
        canvas.drawRoundRect(
            RectF(cx - r * 0.32f, cy - r * 0.35f, cx + r * 0.32f, cy + r * 0.2f),
            r * 0.08f,
            r * 0.08f,
            accent,
        )
        // Stem + base
        canvas.drawRect(cx - r * 0.08f, cy + r * 0.18f, cx + r * 0.08f, cy + r * 0.42f, accent)
        canvas.drawRoundRect(
            RectF(cx - r * 0.28f, cy + r * 0.4f, cx + r * 0.28f, cy + r * 0.55f),
            r * 0.06f,
            r * 0.06f,
            accent,
        )
        // Handles
        stroke.color = momentAccent
        stroke.strokeWidth = r * 0.07f
        stroke.strokeCap = Paint.Cap.ROUND
        canvas.drawArc(
            RectF(cx - r * 0.55f, cy - r * 0.28f, cx - r * 0.18f, cy + r * 0.12f),
            90f,
            180f,
            false,
            stroke,
        )
        canvas.drawArc(
            RectF(cx + r * 0.18f, cy - r * 0.28f, cx + r * 0.55f, cy + r * 0.12f),
            -90f,
            180f,
            false,
            stroke,
        )

        if (withRibbon) {
            soft.color = 0xFFFFF4C8.toInt()
            path.reset()
            path.moveTo(cx - r * 0.2f, cy - r * 0.55f)
            path.lineTo(cx, cy - r * 0.35f)
            path.lineTo(cx + r * 0.2f, cy - r * 0.55f)
            path.lineTo(cx + r * 0.12f, cy - r * 0.22f)
            path.lineTo(cx - r * 0.12f, cy - r * 0.22f)
            path.close()
            canvas.drawPath(path, soft)
            // Medal disc overlay for 30-day
            accent.color = momentAccent
            canvas.drawCircle(cx, cy - r * 0.05f, r * 0.18f, accent)
            disc.color = canvasBg
            canvas.drawCircle(cx, cy - r * 0.05f, r * 0.08f, disc)
        }
    }

    private fun drawStar(canvas: Canvas, x: Float, y: Float, size: Float) {
        path.reset()
        for (i in 0 until 8) {
            val a = Math.PI / 2 + i * Math.PI / 4
            val rad = if (i % 2 == 0) size else size * 0.4f
            val px = x + (cos(a) * rad).toFloat()
            val py = y - (sin(a) * rad).toFloat()
            if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
        }
        path.close()
        canvas.drawPath(path, star)
    }
}
