package com.kiyori.flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var textExchange: TextExchange? = null
    private var modelFile: ModelFile? = null
    private var haptics: Haptics? = null
    private var transientNotice: TransientNotice? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AuditCrypto.initialize()
        textExchange = TextExchange(this, flutterEngine.dartExecutor.binaryMessenger)
        modelFile = ModelFile(this, flutterEngine.dartExecutor.binaryMessenger)
        haptics = Haptics(this, flutterEngine.dartExecutor.binaryMessenger)
        transientNotice = TransientNotice(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (textExchange?.onResult(requestCode, resultCode, data) != true &&
            modelFile?.onResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        transientNotice?.close()
        transientNotice = null
        haptics?.close()
        haptics = null
        textExchange?.close()
        textExchange = null
        modelFile?.close()
        modelFile = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
