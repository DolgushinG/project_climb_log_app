package com.climbingevents.app

import android.os.Bundle
import android.webkit.WebView
import androidx.appcompat.app.AppCompatActivity
import ru.integrationmonitoring.monetasdkapp.MonetaSdk

/**
 * Activity для отображения платёжной формы PayAnyWay (MONETA.RU).
 * Запускается из Flutter через Method Channel.
 */
class PayAnyWayActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_payanyway)

        val orderId = intent.getStringExtra(EXTRA_ORDER_ID) ?: MonetaSdk.getInstance().getOrderId()
        val amount = intent.getDoubleExtra(EXTRA_AMOUNT, 199.0)
        val currency = intent.getStringExtra(EXTRA_CURRENCY) ?: "RUB"
        val paymentSystem = intent.getStringExtra(EXTRA_PAYMENT_SYSTEM) ?: "plastic"

        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        title = "Оплата Premium"

        val webView = findViewById<WebView>(R.id.webView)
        MonetaSdk.getInstance().showPaymentForm(
            orderId,
            amount,
            currency,
            paymentSystem,
            webView,
            this
        )
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    companion object {
        const val EXTRA_ORDER_ID = "order_id"
        const val EXTRA_AMOUNT = "amount"
        const val EXTRA_CURRENCY = "currency"
        const val EXTRA_PAYMENT_SYSTEM = "payment_system"
    }
}
