package com.kiyori

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var textExchange: TextExchange? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        textExchange = TextExchange(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (textExchange?.onResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        textExchange?.close()
        textExchange = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
