package dev.fancontrol.wear;

final class ExerciseOutcome {
    static boolean launchSpotify(String action, boolean requested) {
        return "start_exercise".equals(action) && requested;
    }
    static boolean eligibleSpotifySession(String packageName, boolean localPlayback, boolean pauseSupported) {
        return "com.spotify.music".equals(packageName) && localPlayback && pauseSupported;
    }
}
