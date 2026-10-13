package dev.fancontrol.wear;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.MessageDigest;
import java.security.spec.MGF1ParameterSpec;
import java.util.Base64;
import java.util.concurrent.TimeUnit;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.OAEPParameterSpec;
import javax.crypto.spec.PSource;
import javax.crypto.spec.SecretKeySpec;
import okhttp3.Call;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.json.JSONObject;

/** Setup-only transport for the Home Assistant integration. */
final class PairingClient {
    record Session(String code, String deviceToken, String fingerprint, long expiresAt) {
        @Override public String toString() { return "PairingSession[redacted]"; }
    }
    private final String baseUrl;
    private final OkHttpClient http;
    private volatile Call active;
    private volatile boolean cancelled;

    PairingClient(String url) {
        ConnectionSettings.integrationAddress(url, false);
        baseUrl = url.replaceAll("/+$", "");
        http = new OkHttpClient.Builder().callTimeout(6, TimeUnit.SECONDS).connectTimeout(3, TimeUnit.SECONDS)
                .readTimeout(4, TimeUnit.SECONDS).retryOnConnectionFailure(false).followRedirects(false)
                .followSslRedirects(false).connectionPool(new okhttp3.ConnectionPool(0, 1, TimeUnit.SECONDS)).build();
    }

    private JSONObject request(String action, JSONObject body, String token) throws Exception {
        if (cancelled) throw new IllegalStateException("Cancelled");
        Request.Builder builder = new Request.Builder().url(baseUrl + "/api/fan_control/pair/" + action)
                .post(RequestBody.create(body.toString(), MediaType.get("application/json")));
        if (token != null) builder.header("X-Fan-Control-Pairing", token);
        Call call = http.newCall(builder.build());
        active = call;
        if (cancelled) call.cancel();
        try (Response response = call.execute()) {
            if (!response.isSuccessful() || response.body() == null)
                throw new IllegalStateException(response.code() == 410 ? "Pairing expired" : response.code() == 429 ? "Too many attempts" : "Pairing unavailable");
            String json = response.body().string();
            if (json.length() > 24576) throw new IllegalStateException("Invalid pairing response");
            return new JSONObject(json);
        } finally { active = null; }
    }

    Session create(KeyPair keys) throws Exception {
        byte[] publicKey = keys.getPublic().getEncoded();
        JSONObject response = request("create", new JSONObject().put("public_key", Base64.getEncoder().encodeToString(publicKey)), null);
        String fingerprint = hex(MessageDigest.getInstance("SHA-256").digest(publicKey)).substring(0, 12);
        String code = response.getString("code"), token = response.getString("device_token");
        long expiry = response.getLong("expires_at");
        if (!code.matches("[0-9]{8}") || !token.matches("[a-f0-9]{64}")
                || !fingerprint.equals(response.getString("fingerprint")) || expiry <= System.currentTimeMillis() / 1000
                || expiry > System.currentTimeMillis() / 1000 + 610)
            throw new IllegalStateException("Invalid pairing response");
        return new Session(code, token, fingerprint, expiry);
    }

    JSONObject poll(Session session) throws Exception {
        JSONObject response = request("poll", new JSONObject(), session.deviceToken());
        if (response.getString("status").equals("pending")) return null;
        if (!response.getString("status").equals("ready")) throw new IllegalStateException("Invalid pairing response");
        return response.getJSONObject("envelope");
    }

    void acknowledge(Session session) throws Exception { request("acknowledge", new JSONObject(), session.deviceToken()); }
    void cancel() { cancelled = true; Call call = active; if (call != null) call.cancel(); }

    static ConnectionSettings decrypt(JSONObject envelope, String code, KeyPair keys) throws Exception {
        if (envelope.getInt("version") != 1) throw new IllegalArgumentException("Unsupported pairing version");
        byte[] wrapped = Base64.getDecoder().decode(envelope.getString("wrapped_key"));
        byte[] iv = Base64.getDecoder().decode(envelope.getString("iv"));
        byte[] ciphertext = Base64.getDecoder().decode(envelope.getString("ciphertext"));
        if (wrapped.length != 256 || iv.length != 12 || ciphertext.length < 16 || ciphertext.length > 16384)
            throw new IllegalArgumentException("Invalid encrypted package");
        Cipher rsa = Cipher.getInstance("RSA/ECB/OAEPPadding");
        rsa.init(Cipher.DECRYPT_MODE, keys.getPrivate(), new OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA256, PSource.PSpecified.DEFAULT));
        byte[] key = rsa.doFinal(wrapped);
        if (key.length != 32) throw new IllegalArgumentException("Invalid encryption key");
        Cipher aes = Cipher.getInstance("AES/GCM/NoPadding");
        aes.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(128, iv));
        aes.updateAAD(code.getBytes(StandardCharsets.US_ASCII));
        JSONObject settings = new JSONObject(new String(aes.doFinal(ciphertext), StandardCharsets.UTF_8));
        java.util.Arrays.fill(key, (byte) 0);
        if (settings.getInt("version") != 1) throw new IllegalArgumentException("Unsupported settings version");
        ConnectionSettings result = ConnectionSettings.fromJson(settings);
        if (!result.integration()) throw new IllegalArgumentException("Home Assistant integration pairing required");
        return result;
    }

    private static String hex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte value : bytes) result.append(String.format(java.util.Locale.ROOT, "%02X", value & 0xFF));
        return result.toString();
    }
}
