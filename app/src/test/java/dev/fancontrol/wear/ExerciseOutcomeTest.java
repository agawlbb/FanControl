package dev.fancontrol.wear;
import org.junit.Test;
import static org.junit.Assert.*;
public class ExerciseOutcomeTest {
    @Test public void dispatchAcknowledgementLaunchesWithoutObservedLockState() {
        assertTrue(ExerciseOutcome.launchSpotify("start_exercise",true));
        assertFalse(ExerciseOutcome.launchSpotify("start_exercise",false));
        assertFalse(ExerciseOutcome.launchSpotify("stop_exercise",true));
    }
    @Test public void pauseRequiresExplicitLocalSpotifySessionAndPauseCapability() {
        assertTrue(ExerciseOutcome.eligibleSpotifySession("com.spotify.music",true,true));
        assertFalse(ExerciseOutcome.eligibleSpotifySession("com.spotify.music",false,true));
        assertFalse(ExerciseOutcome.eligibleSpotifySession("com.spotify.music",true,false));
        assertFalse(ExerciseOutcome.eligibleSpotifySession("another.player",true,true));
        assertFalse(ExerciseOutcome.eligibleSpotifySession(null,true,true));
    }
}
