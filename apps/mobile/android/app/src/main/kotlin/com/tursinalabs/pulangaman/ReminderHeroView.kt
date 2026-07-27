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
 * (tidur / belajar / default), drawn without bitmap assets.
 */
class ReminderHeroView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    enum class Mood { SLEEP, STUDY, DEFAULT }

    var mood: Mood = Mood.DEFAULT
        set(value) {
            field = value
            invalidate()
        }

    private val disc = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val accent = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val soft = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val star = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
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
            Mood.DEFAULT -> drawDefault(canvas, cx, cy, r)
        }
    }

    private fun drawSleep(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        soft.color = 0x33FFFFFF
        canvas.drawCircle(cx, cy, r * 1.15f, soft)

        accent.color = 0xFFFFC857.toInt()
        canvas.drawCircle(cx - r * 0.15f, cy - r * 0.05f, r * 0.72f, accent)

        disc.color = 0xFF0B2E28.toInt()
        canvas.drawCircle(cx + r * 0.22f, cy - r * 0.18f, r * 0.58f, disc)

        star.color = 0xFFFFF4C8.toInt()
        drawStar(canvas, cx + r * 0.72f, cy - r * 0.55f, r * 0.08f)
        drawStar(canvas, cx - r * 0.78f, cy + r * 0.15f, r * 0.055f)
        drawStar(canvas, cx + r * 0.55f, cy + r * 0.62f, r * 0.045f)
        drawStar(canvas, cx - r * 0.35f, cy - r * 0.78f, r * 0.04f)

        soft.color = 0x55FFFFFF
        canvas.drawOval(
            RectF(cx - r * 0.55f, cy + r * 0.55f, cx + r * 0.55f, cy + r * 0.95f),
            soft,
        )
    }

    private fun drawStudy(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        soft.color = 0x28FFFFFF
        canvas.drawCircle(cx, cy, r * 1.1f, soft)

        // Open book base
        accent.color = 0xFFFFC857.toInt()
        path.reset()
        path.moveTo(cx - r * 0.7f, cy + r * 0.15f)
        path.quadTo(cx - r * 0.35f, cy - r * 0.35f, cx, cy + r * 0.05f)
        path.quadTo(cx + r * 0.35f, cy - r * 0.35f, cx + r * 0.7f, cy + r * 0.15f)
        path.quadTo(cx + r * 0.2f, cy + r * 0.55f, cx, cy + r * 0.45f)
        path.quadTo(cx - r * 0.2f, cy + r * 0.55f, cx - r * 0.7f, cy + r * 0.15f)
        path.close()
        canvas.drawPath(path, accent)

        disc.color = 0xFF18332D.toInt()
        val spine = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFF18332D.toInt()
            style = Paint.Style.STROKE
            strokeWidth = r * 0.04f
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawLine(cx, cy - r * 0.05f, cx, cy + r * 0.45f, spine)

        // Soft lamp glow
        soft.color = 0x66FFC857
        canvas.drawCircle(cx, cy - r * 0.55f, r * 0.22f, soft)
        accent.color = 0xFFFFE08A.toInt()
        canvas.drawCircle(cx, cy - r * 0.55f, r * 0.12f, accent)

        star.color = 0xCCFFFFFF.toInt()
        drawStar(canvas, cx + r * 0.65f, cy - r * 0.4f, r * 0.05f)
        drawStar(canvas, cx - r * 0.7f, cy - r * 0.25f, r * 0.04f)
    }

    private fun drawDefault(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        soft.color = 0x28FFFFFF
        canvas.drawCircle(cx, cy, r * 1.1f, soft)

        accent.color = 0xFFFFC857.toInt()
        canvas.drawCircle(cx, cy - r * 0.05f, r * 0.42f, accent)

        disc.color = 0xFF18332D.toInt()
        canvas.drawCircle(cx, cy - r * 0.05f, r * 0.28f, disc)

        soft.color = 0xFFFFC857.toInt()
        canvas.drawRoundRect(
            RectF(cx - r * 0.12f, cy + r * 0.32f, cx + r * 0.12f, cy + r * 0.48f),
            r * 0.06f,
            r * 0.06f,
            soft,
        )
        canvas.drawOval(
            RectF(cx - r * 0.22f, cy + r * 0.45f, cx + r * 0.22f, cy + r * 0.58f),
            soft,
        )

        star.color = 0xAAFFFFFF.toInt()
        drawStar(canvas, cx + r * 0.7f, cy - r * 0.5f, r * 0.055f)
        drawStar(canvas, cx - r * 0.75f, cy + r * 0.1f, r * 0.045f)
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
