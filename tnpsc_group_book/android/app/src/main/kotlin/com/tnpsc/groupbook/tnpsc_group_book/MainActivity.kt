package com.tnpsc.groupbook.tnpsc_group_book

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Register all generated plugins (including share_plus)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
