package com.wardrobe_chat.app

import com.google.mlkit.common.MlKit
import io.flutter.app.FlutterApplication

/**
 * Custom Application class. Initializes ML Kit on the main thread so that when the user
 * uses "Detect" on the add-cloth screen, the built-in image labeler works. The default
 * MlKitInitProvider is disabled in the manifest to avoid startup crashes; we init here instead.
 */
class WardrobeApplication : FlutterApplication() {

    override fun onCreate() {
        super.onCreate()
        try {
            MlKit.initialize(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

