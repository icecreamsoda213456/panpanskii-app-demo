package com.example.panpanskii_app

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "panpanskii/share",
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareText") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val text = call.argument<String>("text")?.trim().orEmpty()
            if (text.isEmpty()) {
                result.error("empty_text", "Nothing was provided to share.", null)
                return@setMethodCallHandler
            }

            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            startActivity(Intent.createChooser(sendIntent, "Share Magnetic Hearts room"))
            result.success(null)
        }
    }
}
