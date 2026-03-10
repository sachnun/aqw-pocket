package com.aqw.foreground;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.os.Build;
import android.os.IBinder;

import java.lang.reflect.Constructor;
import java.lang.reflect.Method;

public class AqwForegroundService extends Service {
    public static final String ACTION_START = "com.aqw.foreground.START";
    public static final String ACTION_NOTIFICATION_DISMISSED = "com.aqw.foreground.NOTIFICATION_DISMISSED";
    public static final String ACTION_EXIT = "com.aqw.foreground.EXIT";
    private static final String CHANNEL_ID = "aqw_pocket_foreground";
    private static final int NOTIFICATION_ID = 777001;
    private static volatile boolean keepNotificationPersistent = false;

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        keepNotificationPersistent = true;
        ensureChannelIfNeeded();
        Notification notification = createNotification();
        startForeground(NOTIFICATION_ID, notification);
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        stopForeground(true);
        super.onDestroy();
    }

    public static void disablePersistentNotification() {
        keepNotificationPersistent = false;
    }

    public static boolean shouldKeepNotificationPersistent() {
        return keepNotificationPersistent;
    }

    private void ensureChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < 26) {
            return;
        }
        try {
            NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            if (manager == null) {
                return;
            }
            if (manager.getNotificationChannel(CHANNEL_ID) != null) {
                return;
            }

            Class<?> channelClass = Class.forName("android.app.NotificationChannel");
            Constructor<?> ctor = channelClass.getConstructor(String.class, CharSequence.class, int.class);
            Object channel = ctor.newInstance(CHANNEL_ID, "AQW Pocket Service", NotificationManager.IMPORTANCE_LOW);

            Method setDescription = channelClass.getMethod("setDescription", String.class);
            Method setShowBadge = channelClass.getMethod("setShowBadge", boolean.class);
            setDescription.invoke(channel, "Keeps AQW Pocket alive in background");
            setShowBadge.invoke(channel, false);

            Method createChannel = NotificationManager.class.getMethod("createNotificationChannel", channelClass);
            createChannel.invoke(manager, channel);
        } catch (Exception ignored) {
        }
    }

    @SuppressWarnings("deprecation")
    private Notification createNotification() {
        PendingIntent contentIntent = createOpenAppPendingIntent();

        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);

        builder
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSmallIcon(resolveNotificationIconResId())
                .setContentTitle("AQW Pocket running")
                .setContentText("Background mode active to keep connection alive")
                .setContentIntent(contentIntent)
                .setDeleteIntent(createDismissedPendingIntent())
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Exit", createExitPendingIntent())
                .setWhen(System.currentTimeMillis());

        return builder.build();
    }

    private int resolveNotificationIconResId() {
        String iconName = isDarkTheme() ? "aqw_notify_small_white" : "aqw_notify_small_black";
        int iconResId = getResources().getIdentifier(iconName, "drawable", getPackageName());
        if (iconResId != 0) {
            return iconResId;
        }
        return android.R.drawable.stat_notify_sync;
    }

    private boolean isDarkTheme() {
        int nightMode = getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
        return nightMode == Configuration.UI_MODE_NIGHT_YES;
    }

    private PendingIntent createOpenAppPendingIntent() {
        PackageManager packageManager = getPackageManager();
        Intent launchIntent = packageManager.getLaunchIntentForPackage(getPackageName());

        if (launchIntent == null) {
            return null;
        }

        launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }

        return PendingIntent.getActivity(this, 0, launchIntent, flags);
    }

    private PendingIntent createDismissedPendingIntent() {
        Intent dismissedIntent = new Intent(this, NotificationDismissedReceiver.class);
        dismissedIntent.setAction(ACTION_NOTIFICATION_DISMISSED);

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }

        return PendingIntent.getBroadcast(this, 1, dismissedIntent, flags);
    }

    private PendingIntent createExitPendingIntent() {
        Intent exitIntent = new Intent(this, NotificationDismissedReceiver.class);
        exitIntent.setAction(ACTION_EXIT);

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }

        return PendingIntent.getBroadcast(this, 2, exitIntent, flags);
    }
}
