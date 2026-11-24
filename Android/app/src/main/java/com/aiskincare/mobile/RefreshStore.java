package com.aiskincare.mobile;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

final class RefreshStore {
    private static final String KEY = "skincare.session.aes.v1";
    private final String server;
    private final SharedPreferences prefs;

    RefreshStore(Context context, String server) {
        this.server = server;
        prefs = context.getSharedPreferences("sessions", Context.MODE_PRIVATE);
    }
    boolean hasSession() { return prefs.contains(server); }
    void clear() { prefs.edit().remove(server).commit(); }

    private static synchronized SecretKey key() throws Exception {
        KeyStore keys = KeyStore.getInstance("AndroidKeyStore");
        keys.load(null);
        if (keys.containsAlias(KEY)) return (SecretKey) keys.getKey(KEY, null);
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(KEY, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return generator.generateKey();
    }
    void write(String value) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, key());
        cipher.updateAAD(server.getBytes(StandardCharsets.UTF_8));
        byte[] body = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
        byte[] iv = cipher.getIV();
        byte[] record = Arrays.copyOf(iv, iv.length + body.length);
        System.arraycopy(body, 0, record, iv.length, body.length);
        if (!prefs.edit().putString(server, Base64.encodeToString(record, Base64.NO_WRAP)).commit())
            throw new java.io.IOException("로그인 정보를 저장하지 못했어요.");
    }
    String read() {
        String record = prefs.getString(server, null);
        if (record == null) return "";
        try {
            byte[] bytes = Base64.decode(record, Base64.NO_WRAP);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, bytes, 0, 12));
            cipher.updateAAD(server.getBytes(StandardCharsets.UTF_8));
            return new String(cipher.doFinal(bytes, 12, bytes.length - 12), StandardCharsets.UTF_8);
        } catch (Exception unavailable) { clear(); return ""; }
    }
}
