package com.aqw.foreground;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import java.lang.reflect.Method;

public class NotificationDismissedReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) {
            return;
        }

        String action = intent.getAction();
        if (AqwForegroundService.ACTION_EXIT.equals(action)) {
            handleExit(context);
            return;
        }

        if (!AqwForegroundService.ACTION_NOTIFICATION_DISMISSED.equals(action)) {
            return;
        }

        if (!AqwForegroundService.shouldKeepNotificationPersistent()) {
            return;
        }

        Context appContext = context.getApplicationContext();
        Intent serviceIntent = new Intent(appContext, AqwForegroundService.class);
        serviceIntent.setAction(AqwForegroundService.ACTION_START);

        if (!startForegroundCompat(appContext, serviceIntent)) {
            appContext.startService(serviceIntent);
        }
    }

    private void handleExit(Context context) {
        Context appContext = context.getApplicationContext();
        AqwForegroundService.disablePersistentNotification();
        Intent serviceIntent = new Intent(appContext, AqwForegroundService.class);
        appContext.stopService(serviceIntent);
    }

    private boolean startForegroundCompat(Context context, Intent intent) {
        if (Build.VERSION.SDK_INT < 26) {
            return false;
        }

        try {
            Method method = Context.class.getMethod("startForegroundService", Intent.class);
            method.invoke(context, intent);
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }
}
