package dev.fancontrol.wear;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.SecureRandom;
import java.security.spec.MGF1ParameterSpec;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.OAEPParameterSpec;
import javax.crypto.spec.PSource;
import javax.crypto.spec.SecretKeySpec;
import org.json.JSONObject;
import org.junit.Test;
import static org.junit.Assert.*;

public class PairingClientTest {
    private JSONObject encrypt(KeyPair pair, String code) throws Exception {
        byte[] key = new byte[32], iv = new byte[12]; new SecureRandom().nextBytes(key); new SecureRandom().nextBytes(iv);
        Cipher aes = Cipher.getInstance("AES/GCM/NoPadding");
        aes.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(128, iv));
        aes.updateAAD(code.getBytes(StandardCharsets.US_ASCII));
        byte[] data = aes.doFinal("{\"version\":1,\"url\":\"https://ha.example.com\",\"entity\":\"fan.example\",\"token\":\"1212121212121212121212121212121212121212121212121212121212121212\",\"integration\":true,\"watch_id\":\"abababababababababababababababab\"}".getBytes(StandardCharsets.UTF_8));
        Cipher rsa = Cipher.getInstance("RSA/ECB/OAEPPadding");
        rsa.init(Cipher.ENCRYPT_MODE, pair.getPublic(), new OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA256, PSource.PSpecified.DEFAULT));
        return new JSONObject().put("version", 1).put("wrapped_key", Base64.getEncoder().encodeToString(rsa.doFinal(key)))
                .put("iv", Base64.getEncoder().encodeToString(iv)).put("ciphertext", Base64.getEncoder().encodeToString(data));
    }
    private KeyPair keys() throws Exception { KeyPairGenerator gen = KeyPairGenerator.getInstance("RSA"); gen.initialize(2048); return gen.generateKeyPair(); }
    @Test public void decryptsHomeAssistantProtocol() throws Exception {
        KeyPair pair = keys(); ConnectionSettings settings = PairingClient.decrypt(encrypt(pair, "12345678"), "12345678", pair);
        assertEquals("https://ha.example.com", settings.baseUrl()); assertTrue(settings.integration());
    }
    @Test(expected = javax.crypto.AEADBadTagException.class) public void differentCodeCannotAuthenticatePackage() throws Exception {
        KeyPair pair = keys(); PairingClient.decrypt(encrypt(pair, "12345678"), "87654321", pair);
    }
    @Test(expected = javax.crypto.BadPaddingException.class) public void differentWatchCannotDecryptPackage() throws Exception {
        KeyPair pair = keys(); PairingClient.decrypt(encrypt(pair, "12345678"), "12345678", keys());
    }
    @Test(expected = IllegalArgumentException.class) public void rejectsNonHttpsPairingService() { new PairingClient("http://pair.example.com"); }
}
