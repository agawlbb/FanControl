package dev.fancontrol.wear;

import org.junit.Test;
import static org.junit.Assert.*;

public class PairingProgressTest {
    private ConnectionSettings connection(String token) {
        return ConnectionSettings.validate("https://ha.example.com", token, "fan.example");
    }
    @Test public void initialSetupWaitsUntilSettingsActuallyExist() {
        PairingProgress progress = new PairingProgress("");
        assertFalse(progress.hasConnected(null, false));
        assertTrue(progress.hasConnected(connection("test-token"), false));
    }
    @Test public void restoredCompletedSetupDoesNotPairAgain() {
        ConnectionSettings saved = connection("test-token");
        assertTrue(new PairingProgress("").hasConnected(saved, false));
        assertTrue(new PairingProgress(PairingProgress.key(saved)).hasConnected(saved, true));
    }
    @Test public void deliberateReplacementWaitsForTheNewConnection() {
        ConnectionSettings previous = connection("old-test-token");
        PairingProgress progress = new PairingProgress(PairingProgress.key(previous));
        assertFalse(progress.hasConnected(previous, false));
        assertTrue(progress.hasConnected(connection("new-test-token"), false));
    }
    @Test public void lostSettingsNeverCountAsConnected() {
        assertFalse(new PairingProgress("").hasConnected(null, true));
    }
    @Test public void savedBaselineDoesNotContainCredentialsOrAddress() {
        String key = PairingProgress.key(connection("test-token"));
        assertTrue(key.matches("[a-f0-9]{64}"));
        assertFalse(key.contains("test-token")); assertFalse(key.contains("example"));
    }
}
