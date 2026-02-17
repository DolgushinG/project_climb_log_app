package ru.integrationmonitoring.monetasdkapp;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;
import android.webkit.URLUtil;
import android.os.Build;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
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
     * @param mntPaymentSystem Payment system: "plastic" = cards only, "all" = all methods (cards, SBP, SberPay, etc.)
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

        boolean showAllMethods = "all".equalsIgnoreCase(mntPaymentSystem) || mntPaymentSystem == null || mntPaymentSystem.isEmpty();
        String mntPaymentSystemAccountId = showAllMethods ? "" : sdkConfig.get(mntPaymentSystem + "_accountId");
        String mntPaymentSystemUnitId = showAllMethods ? "" : sdkConfig.get(mntPaymentSystem + "_unitId");
        String mntAccountId = sdkConfig.get("monetasdk_account_id");
        String mntAccountCode = sdkConfig.get("monetasdk_account_code");
        String mntDemoMode = sdkConfig.get("monetasdk_demo_mode");
        String mntTestMode = sdkConfig.get("monetasdk_test_mode");
        String mntDemoUrl = sdkConfig.get("monetasdk_demo_url");
        String mntProdUrl = sdkConfig.get("monetasdk_production_url");
        String mntWidgLink = sdkConfig.get("monetasdk_assistant_widget_link");
        String mntSuccessUrl = sdkConfig.get("monetasdk_success_url");
        String mntFailUrl = sdkConfig.get("monetasdk_fail_url");

        String mntAmountString = String.format("%.2f", mntAmount).replace(",", ".");
        String mntWidgUrl = "1".equals(mntDemoMode) ? mntDemoUrl : mntProdUrl;
        mntWidgUrl = mntWidgUrl + mntWidgLink;

        String queryString = mntWidgUrl + "?MNT_ID=" + mntAccountId
                + "&MNT_TRANSACTION_ID=" + mntOrderId
                + "&MNT_CURRENCY_CODE=" + mntCurrency
                + "&MNT_AMOUNT=" + mntAmountString
                + "&followup=true&javascriptEnabled=true"
                + "&MNT_TEST_MODE=" + mntTestMode;
        if (!showAllMethods && mntPaymentSystemUnitId != null && !mntPaymentSystemUnitId.isEmpty()) {
            queryString = queryString + "&payment_method=" + mntPaymentSystem
                    + "&paymentSystem.unitId=" + mntPaymentSystemUnitId
                    + "&paymentSystem.limitIds=" + mntPaymentSystemUnitId
                    + "&paymentSystem.accountId=" + mntPaymentSystemAccountId;
        }
        try {
            if (!mntSuccessUrl.isEmpty()) {
                queryString = queryString + "&MNT_SUCCESS_URL=" + URLEncoder.encode(mntSuccessUrl, "UTF-8");
            }
            if (!mntFailUrl.isEmpty()) {
                queryString = queryString + "&MNT_FAIL_URL=" + URLEncoder.encode(mntFailUrl, "UTF-8");
            }
        } catch (UnsupportedEncodingException e) {
            Log.e(TAG, "URL encode error", e);
        }

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
        // Блокировать window.open() — страница Moneta при закрытии может открывать браузер.
        webView.getSettings().setSupportMultipleWindows(true);
        webView.getSettings().setJavaScriptCanOpenWindowsAutomatically(true);
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onCreateWindow(WebView view, boolean isDialog, boolean isUserGesture, android.os.Message resultMsg) {
                // Возвращаем false — не открывать новое окно/браузер.
                return false;
            }
        });
        webView.setInitialScale(1);
        webView.setWebViewClient(new PaymentWebViewClient(context, mntSuccessUrl, mntFailUrl));
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

    /**
     * WebViewClient that intercepts climbingevents:// redirects (success/fail) and closes the payment activity.
     */
    private static class PaymentWebViewClient extends WebViewClient {
        private final Context context;
        private final String successUrl;
        private final String failUrl;

        PaymentWebViewClient(Context context, String successUrl, String failUrl) {
            this.context = context;
            this.successUrl = successUrl != null ? successUrl : "";
            this.failUrl = failUrl != null ? failUrl : "";
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && request.isForMainFrame()) {
                String url = request.getUrl() != null ? request.getUrl().toString() : null;
                return handleUrl(url);
            }
            return false;
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            return handleUrl(url);
        }

        private boolean handleUrl(String url) {
            if (url == null || url.isEmpty()) return false;
            if (isOurDeepLink(url)) {
                if (context instanceof Activity) {
                    Activity activity = (Activity) context;
                    boolean isSuccess = url.contains("success") || url.equals(successUrl);
                    activity.setResult(isSuccess ? Activity.RESULT_OK : Activity.RESULT_CANCELED);
                    activity.finish();
                }
                return true;
            }
            // СБП и банковские приложения: bank110000000005://, sbp:// и др.
            // Не открывать внешние приложения, если Activity закрывается (пользователь нажал «Назад»).
            if (!URLUtil.isNetworkUrl(url)) {
                if (context instanceof Activity && ((Activity) context).isFinishing()) {
                    return true;
                }
                try {
                    Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                    if (!(context instanceof Activity)) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    }
                    context.startActivity(intent);
                } catch (ActivityNotFoundException e) {
                    Log.w(TAG, "No app to handle: " + url);
                }
                return true;
            }
            return false;
        }

        private boolean isOurDeepLink(String url) {
            if (url == null || url.isEmpty()) return false;
            return url.startsWith("climbingevents://")
                    || url.equals(successUrl)
                    || url.equals(failUrl);
        }
    }
}
