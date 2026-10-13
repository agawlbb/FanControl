package dev.fancontrol.wear;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import org.json.JSONObject;

/** Encrypt all connection details with a non-exportable Android Keystore key. */
public final class SecureSettings {
    private static final String ALIAS = "fan-control-settings-v1";
    // Setup, controls, and the tile use different storage instances in the same process.
    private static final Object LOCK = new Object();
    private final SharedPreferences preferences;

    public SecureSettings(Context context) {
        preferences = context.getSharedPreferences("connection", Context.MODE_PRIVATE);
    }

    private SecretKey key() throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        if (!store.containsAlias(ALIAS)) {
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build());
            generator.generateKey();
        }
        return (SecretKey) store.getKey(ALIAS, null);
    }

    public void save(ConnectionSettings settings) throws Exception {
        synchronized (LOCK) {
            JSONObject json = settings.toJson();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key());
            String encrypted = Base64.encodeToString(cipher.doFinal(json.toString().getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
            if (!preferences.edit().putString("data", encrypted)
                    .putString("iv", Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP)).commit())
                throw new IllegalStateException("Could not save settings");
        }
    }

    public ConnectionSettings load() {
        synchronized (LOCK) {
            try {
                // Read ciphertext and IV from one revision rather than two independent reads.
                java.util.Map<String, ?> snapshot = preferences.getAll();
                if (!snapshot.containsKey("data")) return null;
                Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
                cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128,
                        Base64.decode((String)snapshot.get("iv"), Base64.NO_WRAP)));
                JSONObject json = new JSONObject(new String(cipher.doFinal(
                        Base64.decode((String)snapshot.get("data"), Base64.NO_WRAP)), StandardCharsets.UTF_8));
                return ConnectionSettings.fromJson(json);
            } catch (Exception ignored) { return null; } // Never log connection details or secrets.
        }
    }

    public void clear() throws Exception {
        synchronized (LOCK) {
            if (!preferences.edit().clear().commit()) throw new IllegalStateException("Could not clear settings");
            KeyStore store = KeyStore.getInstance("AndroidKeyStore");
            store.load(null);
            store.deleteEntry(ALIAS);
        }
    }
}
