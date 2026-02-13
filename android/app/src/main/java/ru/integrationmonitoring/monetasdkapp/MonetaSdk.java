package ru.integrationmonitoring.monetasdkapp;

import android.content.Context;
import android.util.Log;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Random;

/**
 * PayAnyWay (MONETA.RU) Android SDK.
 * Displays payment form in WebView via MONETA.Assistant.
 * @see <a href="https://payanyway.ru/info/p/ru/public/merchants/SDKandroid.pdf">SDK PDF</a>
 */
public class MonetaSdk {

    private static final String TAG = "MonetaSdk";

    /**
     * Show payment form in WebView.
     * @param mntOrderId Unique order identifier
     * @param mntAmount Amount (e.g. 199.00)
     * @param mntCurrency Currency code (e.g. RUB)
     * @param mntPaymentSystem Payment system (e.g. "plastic" for cards)
     * @param webView WebView to load the form
     * @param context Context
     */
    public void showPaymentForm(String mntOrderId, Double mntAmount, String mntCurrency,
                                String mntPaymentSystem, WebView webView, Context context) {
        MonetaSdkConfig sdkConfig = new MonetaSdkConfig();
        if (!sdkConfig.load(context)) {
            Log.e(TAG, "Failed to load SDK config");
            return;
        }

        String mntPaymentSystemAccountId = sdkConfig.get(mntPaymentSystem + "_accountId");
        String mntPaymentSystemUnitId = sdkConfig.get(mntPaymentSystem + "_unitId");
        String mntAccountId = sdkConfig.get("monetasdk_account_id");
        String mntAccountCode = sdkConfig.get("monetasdk_account_code");
        String mntDemoMode = sdkConfig.get("monetasdk_demo_mode");
        String mntTestMode = sdkConfig.get("monetasdk_test_mode");
        String mntDemoUrl = sdkConfig.get("monetasdk_demo_url");
        String mntProdUrl = sdkConfig.get("monetasdk_production_url");
        String mntWidgLink = sdkConfig.get("monetasdk_assistant_widget_link");

        String mntAmountString = String.format("%.2f", mntAmount).replace(",", ".");
        String mntWidgUrl = "1".equals(mntDemoMode) ? mntDemoUrl : mntProdUrl;
        mntWidgUrl = mntWidgUrl + mntWidgLink;

        String queryString = mntWidgUrl + "?MNT_ID=" + mntAccountId
                + "&MNT_TRANSACTION_ID=" + mntOrderId
                + "&MNT_CURRENCY_CODE=" + mntCurrency
                + "&MNT_AMOUNT=" + mntAmountString
                + "&followup=true&javascriptEnabled=true&payment_method=" + mntPaymentSystem
                + "&paymentSystem.unitId=" + mntPaymentSystemUnitId
                + "&paymentSystem.limitIds=" + mntPaymentSystemUnitId
                + "&paymentSystem.accountId=" + mntPaymentSystemAccountId
                + "&MNT_TEST_MODE=" + mntTestMode;

        if (!mntAccountCode.isEmpty()) {
            queryString = queryString + "&MNT_SIGNATURE=" + md5(mntAccountId + mntOrderId
                    + mntAmountString + mntCurrency + mntTestMode + mntAccountCode);
        }

        Log.d(TAG, "Payment URL: " + queryString);

        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDisplayZoomControls(true);
        webView.getSettings().setLoadWithOverviewMode(true);
        webView.getSettings().setUseWideViewPort(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.setInitialScale(1);
        webView.setWebViewClient(new WebViewClient());
        webView.loadUrl(queryString);
    }

    public static String md5(final String s) {
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            digest.update(s.getBytes());
            byte[] messageDigest = digest.digest();
            StringBuilder hexString = new StringBuilder();
            for (byte b : messageDigest) {
                String h = Integer.toHexString(0xFF & b);
                if (h.length() < 2) h = "0" + h;
                hexString.append(h);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            Log.e(TAG, "MD5 error", e);
            return "";
        }
    }

    /**
     * Generate unique order ID.
     */
    public String getOrderId() {
        long ts = System.currentTimeMillis();
        int rnd = new Random().nextInt(90) + 10;
        return ts + "" + rnd;
    }

    private static final MonetaSdk instance = new MonetaSdk();

    public static MonetaSdk getInstance() {
        return instance;
    }

    private MonetaSdk() {
    }
}
