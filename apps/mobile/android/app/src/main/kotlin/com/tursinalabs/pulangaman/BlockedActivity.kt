package com.tursinalabs.pulangaman

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class BlockedActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val packageName = intent.getStringExtra("blockedPackage") ?: "aplikasi ini"
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(Color.rgb(255, 251, 243))
        }
        layout.addView(TextView(this).apply {
            text = "Waktunya istirahat"
            textSize = 30f
            setTextColor(Color.rgb(7, 88, 78))
            gravity = Gravity.CENTER
        })
        layout.addView(TextView(this).apply {
            text = "$packageName sedang dibatasi oleh aturan keluarga."
            textSize = 17f
            setTextColor(Color.rgb(24, 51, 45))
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 32)
        })
        layout.addView(Button(this).apply {
            text = "Kembali ke PulangAman"
            setOnClickListener {
                packageManager.getLaunchIntentForPackage(applicationContext.packageName)?.let {
                    startActivity(it)
                }
                finish()
            }
        })
        layout.addView(Button(this).apply {
            text = "Panggilan darurat"
            setOnClickListener {
                startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:112")))
            }
        })
        setContentView(layout)
    }
}
