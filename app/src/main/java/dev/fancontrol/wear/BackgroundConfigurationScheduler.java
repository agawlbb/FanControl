package dev.fancontrol.wear;

import android.app.job.JobInfo;
import android.app.job.JobScheduler;
import android.content.ComponentName;
import android.content.Context;

final class BackgroundConfigurationScheduler {
    static final int JOB_ID = 15001;
    static final long INTERVAL_MS = 15 * 60 * 1000L;
    static final long FLEX_MS = 5 * 60 * 1000L;
    static void ensure(Context context, ConnectionSettings settings) {
        JobScheduler scheduler = context.getSystemService(JobScheduler.class);
        if (settings == null || !settings.integration()) {
            scheduler.cancel(JOB_ID);
            BackgroundConfigurationJob.cancelActive();
        } else if (scheduler.getPendingJob(JOB_ID) == null) {
            scheduler.schedule(new JobInfo.Builder(JOB_ID, new ComponentName(context, BackgroundConfigurationJob.class))
                    .setPeriodic(INTERVAL_MS, FLEX_MS).setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setRequiresBatteryNotLow(true).setPersisted(true).build());
        }
    }
}
