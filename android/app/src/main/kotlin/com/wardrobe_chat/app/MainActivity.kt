package com.wardrobe_chat.app

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Enable edge-to-edge for Android 15+ (SDK 35) compatibility
        // Ensures app displays correctly when targeting SDK 35
        WindowCompat.enableEdgeToEdge(window)
    }
}

