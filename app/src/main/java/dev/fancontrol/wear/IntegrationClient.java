package dev.fancontrol.wear;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.concurrent.TimeUnit;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import okhttp3.*;
import org.json.JSONObject;

/** Encrypted HA reads/commands for visible controls and bounded configuration checks. */
final class IntegrationClient implements VisibleConfigurationSession.Client {
    private final ConnectionSettings settings;
    private final OkHttpClient http;
    private volatile Call active;
    private volatile boolean cancelled;
    private String endpoint;
    private static final java.util.concurrent.ConcurrentHashMap<String, String> endpoints = new java.util.concurrent.ConcurrentHashMap<>();
    IntegrationClient(ConnectionSettings settings) {
        this(settings, new OkHttpClient.Builder().callTimeout(6000, TimeUnit.MILLISECONDS)
                .connectTimeout(1500, TimeUnit.MILLISECONDS).readTimeout(5, TimeUnit.SECONDS)
                .retryOnConnectionFailure(false).followRedirects(false).followSslRedirects(false)
                .connectionPool(new ConnectionPool(0, 1, TimeUnit.SECONDS)).build());
    }
    IntegrationClient(ConnectionSettings settings, OkHttpClient http) { this.settings = settings; this.http = http; endpoint = endpoints.getOrDefault(routeKey(settings), settings.baseUrl());
        if (!endpoint.equals(settings.baseUrl()) && !endpoint.equals(settings.remoteUrl())) endpoint = settings.baseUrl(); }
    private static String routeKey(ConnectionSettings settings) { return settings.watchId() + "\n" + settings.baseUrl() + "\n" + settings.remoteUrl(); }
    public void cancel() { cancelled = true; Call call = active; if (call != null) call.cancel(); }
    JSONObject request(JSONObject body) throws Exception {
        if (cancelled) throw new IOException("Cancelled");
        try { JSONObject result = exchange(endpoint, body); endpoints.put(routeKey(settings), endpoint); return result; }
        catch (IOException failure) {
            // Never replay a command through another endpoint after an ambiguous response.
            if (cancelled || java.util.List.of("command", "panel_command").contains(body.optString("action")) || settings.remoteUrl().isEmpty()
                    || settings.remoteUrl().equals(settings.baseUrl()) || failure instanceof Rejected) throw failure;
            String fallback = endpoint.equals(settings.remoteUrl()) ? settings.baseUrl() : settings.remoteUrl();
            JSONObject result = exchange(fallback, body); endpoint = fallback; endpoints.put(routeKey(settings), endpoint); return result;
        }
    }
    private JSONObject exchange(String url, JSONObject body) throws Exception {
        byte[] iv = new byte[12], nonce = new byte[16]; SecureRandom random = new SecureRandom(); random.nextBytes(iv); random.nextBytes(nonce);
        long timestamp = System.currentTimeMillis() / 1000;
        String aad = "fan-control-v1:" + settings.watchId() + ":" + timestamp + ":" + hex(nonce);
        byte[] key = unhex(settings.token());
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(128, iv));
        cipher.updateAAD(aad.getBytes(StandardCharsets.US_ASCII));
        JSONObject packet = new JSONObject().put("watch_id", settings.watchId()).put("timestamp", timestamp).put("nonce", hex(nonce))
                .put("iv", Base64.getEncoder().encodeToString(iv)).put("ciphertext", Base64.getEncoder().encodeToString(cipher.doFinal(body.toString().getBytes(StandardCharsets.UTF_8))));
        Call call = http.newCall(new Request.Builder().url(url + "/api/fan_control/watch/request")
                .post(RequestBody.create(packet.toString(), MediaType.get("application/json"))).build());
        active = call; if (cancelled) call.cancel();
        try (Response response = call.execute()) {
            if (!response.isSuccessful()) throw new Rejected(response.code());
            if (response.body() == null) throw new IOException("Empty response");
            String raw = response.body().string(); if (raw.length() > 24576) throw new IOException("Invalid response");
            JSONObject envelope = new JSONObject(raw);
            byte[] responseIv = Base64.getDecoder().decode(envelope.getString("iv"));
            if (responseIv.length != 12) throw new IOException("Invalid response");
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(128, responseIv));
            cipher.updateAAD((aad + ":response").getBytes(StandardCharsets.US_ASCII));
            return new JSONObject(new String(cipher.doFinal(Base64.getDecoder().decode(envelope.getString("ciphertext"))), StandardCharsets.UTF_8));
        } finally { active = null; java.util.Arrays.fill(key, (byte)0); }
    }
    public ConnectionSettings configuration() throws Exception {
        JSONObject config = request(new JSONObject().put("action", "config"));
        config.put("token", settings.token()).put("watch_id", settings.watchId()).put("integration", true);
        return ConnectionSettings.fromJson(config);
    }
    static String hex(byte[] bytes) {
        StringBuilder text = new StringBuilder(); for (byte value : bytes) text.append(String.format(java.util.Locale.ROOT, "%02x", value & 255)); return text.toString();
    }
    static byte[] unhex(String text) {
        byte[] bytes = new byte[text.length()/2]; for (int i=0;i<bytes.length;i++) bytes[i]=(byte)Integer.parseInt(text.substring(i*2,i*2+2),16); return bytes;
    }
    static boolean accessRevoked(Exception failure) { return failure instanceof Rejected rejection && (rejection.status == 401 || rejection.status == 403); }
    static final class Rejected extends IOException {
        final int status;
        Rejected(int status) { super("Home Assistant rejected watch access"); this.status = status; }
    }
}
