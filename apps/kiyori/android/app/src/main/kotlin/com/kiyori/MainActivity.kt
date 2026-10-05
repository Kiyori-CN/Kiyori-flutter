package com.kiyori

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var textExchange: TextExchange? = null
    private var modelFile: ModelFile? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AuditCrypto.initialize()
        textExchange = TextExchange(this, flutterEngine.dartExecutor.binaryMessenger)
        modelFile = ModelFile(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (textExchange?.onResult(requestCode, resultCode, data) != true &&
            modelFile?.onResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        textExchange?.close()
        textExchange = null
        modelFile?.close()
        modelFile = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
