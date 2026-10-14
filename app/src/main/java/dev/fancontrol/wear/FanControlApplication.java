package dev.fancontrol.wear;

import android.app.Activity;
import android.app.Application;
import android.os.Bundle;

public final class FanControlApplication extends Application implements Application.ActivityLifecycleCallbacks {
    private static volatile int resumed;
    static boolean foreground() { return resumed > 0 || TileSession.isVisible(); }
    @Override public void onCreate() {
        super.onCreate(); registerActivityLifecycleCallbacks(this);
        BackgroundConfigurationScheduler.ensure(this, new SecureSettings(this).load());
    }
    @Override public void onActivityResumed(Activity activity) { resumed++; BackgroundConfigurationJob.cancelActive(); }
    @Override public void onActivityPaused(Activity activity) { resumed = Math.max(0, resumed - 1); }
    @Override public void onActivityCreated(Activity activity, Bundle state) { }
    @Override public void onActivityStarted(Activity activity) { }
    @Override public void onActivityStopped(Activity activity) { }
    @Override public void onActivitySaveInstanceState(Activity activity, Bundle state) { }
    @Override public void onActivityDestroyed(Activity activity) { }
}
