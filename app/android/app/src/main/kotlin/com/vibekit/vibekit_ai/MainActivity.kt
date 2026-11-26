package com.vibekit.vibekit_ai

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.vibekit.vibekit_ai/share_intent"
    }

    private var pendingSharedText: String? = null
    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractSharedText(intent)?.let { text ->
            pendingSharedText = text
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialSharedText") {
                    result.success(pendingSharedText)
                    pendingSharedText = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractSharedText(intent)?.let { text ->
            if (shareChannel != null) {
                shareChannel?.invokeMethod("onSharedText", text)
            } else {
                pendingSharedText = text
            }
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            return intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()?.takeIf { it.isNotEmpty() }
        }
        return null
    }
}
