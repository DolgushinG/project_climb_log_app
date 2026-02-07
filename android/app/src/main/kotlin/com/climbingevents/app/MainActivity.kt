package com.climbingevents.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tracer_test_channel"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "nativeTestCrash" -> {
                    // Интентциональный крэш для проверки интеграции Tracer
                    throw RuntimeException("Tracer test crash from native code")
                }

                else -> result.notImplemented()
            }
        }
    }
}
