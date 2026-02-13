package ru.integrationmonitoring.monetasdkapp;

import android.content.Context;
import java.io.IOException;
import java.util.Properties;

/**
 * PayAnyWay (MONETA.RU) SDK configuration loader.
 * Loads INI files from assets.
 */
public class MonetaSdkConfig {

    private Properties configuration;

    public MonetaSdkConfig() {
        configuration = new Properties();
    }

    public boolean load(Context context) {
        try {
            configuration.load(context.getAssets().open("android_basic_settings.ini"));
            configuration.load(context.getAssets().open("android_payment_systems.ini"));
            configuration.load(context.getAssets().open("error_texts.ini"));
            configuration.load(context.getAssets().open("payment_urls.ini"));
            return true;
        } catch (IOException e) {
            android.util.Log.e("MonetaSdkConfig", "Configuration error: " + e.getMessage());
            return false;
        }
    }

    public void set(String key, String value) {
        configuration.setProperty(key, value);
    }

    public String get(String key) {
        String v = configuration.getProperty(key);
        if (v == null) return "";
        return v.replace("\"", "").trim();
    }
}
