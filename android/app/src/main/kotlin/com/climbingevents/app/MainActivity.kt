package com.climbingevents.app

import android.content.Intent
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
                    throw RuntimeException("Tracer test crash from native code")
                }
                else -> result.notImplemented()
            }
        }

        // PayAnyWay (MONETA.RU) — нативный SDK Android
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.climbingevents.app/payanyway"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showPayment" -> {
                    val orderId = call.argument<String>("orderId")
                    val amount = call.argument<Double>("amount") ?: 199.0
                    val currency = call.argument<String>("currency") ?: "RUB"
                    val intent = Intent(this, PayAnyWayActivity::class.java).apply {
                        orderId?.let { putExtra(PayAnyWayActivity.EXTRA_ORDER_ID, it) }
                        putExtra(PayAnyWayActivity.EXTRA_AMOUNT, amount)
                        putExtra(PayAnyWayActivity.EXTRA_CURRENCY, currency)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
