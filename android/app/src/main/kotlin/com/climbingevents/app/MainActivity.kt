package com.climbingevents.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val REQUEST_PAY_ANYWAY = 1001
    }

    private var payAnyWayResult: MethodChannel.Result? = null

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
                    payAnyWayResult = result
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, REQUEST_PAY_ANYWAY)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PAY_ANYWAY) {
            payAnyWayResult?.success(resultCode == RESULT_OK)
            payAnyWayResult = null
        }
    }
}
