package dev.fancontrol.wear;

import android.app.NotificationManager;
import android.content.ComponentName;
import android.content.Context;
import android.media.session.MediaSessionManager;
import android.media.session.MediaController;
import android.media.session.PlaybackState;

/** Never dispatch a broad media key or control Spotify Connect's active remote device. */
final class WatchSpotify {
    static boolean hasAccess(Context context) {
        return context.getSystemService(NotificationManager.class).isNotificationListenerAccessGranted(
                new ComponentName(context, SpotifyNotificationAccess.class));
    }
    static String pause(Context context) {
        if (!hasAccess(context)) return "Spotify pause needs notification access";
        try {
            java.util.List<MediaController> targets = context.getSystemService(MediaSessionManager.class).getActiveSessions(
                    new ComponentName(context, SpotifyNotificationAccess.class)).stream().filter(session -> {
                PlaybackState state = session.getPlaybackState();
                MediaController.PlaybackInfo info = session.getPlaybackInfo();
                return ExerciseOutcome.eligibleSpotifySession(session.getPackageName(),
                        info != null && info.getPlaybackType() == MediaController.PlaybackInfo.PLAYBACK_TYPE_LOCAL,
                        state != null && (state.getActions() & PlaybackState.ACTION_PAUSE) != 0);
            }).collect(java.util.stream.Collectors.toList());
            if (targets.size() != 1) return targets.isEmpty() ? "No supported local Spotify session" : "Spotify pause unavailable: ambiguous sessions";
            targets.get(0).getTransportControls().pause();
            return "Watch Spotify pause requested";
        } catch (RuntimeException unavailable) { return "Watch Spotify pause unavailable"; }
    }
}
