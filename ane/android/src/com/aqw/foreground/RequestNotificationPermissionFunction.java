package com.aqw.foreground;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import com.adobe.fre.FREContext;
import com.adobe.fre.FREFunction;
import com.adobe.fre.FREObject;

import java.lang.reflect.Method;

public class RequestNotificationPermissionFunction implements FREFunction {
    private static final String POST_NOTIFICATIONS_PERMISSION = "android.permission.POST_NOTIFICATIONS";
    private static final int REQUEST_CODE = 777001;

    @Override
    public FREObject call(FREContext context, FREObject[] args) {
        try {
            if (Build.VERSION.SDK_INT < 33) {
                return FREObject.newObject(true);
            }

            Activity activity = context.getActivity();
            if (activity == null) {
                return FREObject.newObject(false);
            }

            Context appContext = activity.getApplicationContext();
            if (hasNotificationPermission(appContext)) {
                return FREObject.newObject(true);
            }

            requestPermission(activity);
            return FREObject.newObject(true);
        } catch (Exception e) {
            context.dispatchStatusEventAsync("FGS_ERROR", e.getMessage() != null ? e.getMessage() : "permission request failed");
            try {
                return FREObject.newObject(false);
            } catch (Exception ignored) {
                return null;
            }
        }
    }

    private boolean hasNotificationPermission(Context context) {
        try {
            Method checkSelfPermission = Context.class.getMethod("checkSelfPermission", String.class);
            Object result = checkSelfPermission.invoke(context, POST_NOTIFICATIONS_PERMISSION);
            return result instanceof Integer && (Integer) result == PackageManager.PERMISSION_GRANTED;
        } catch (Exception ignored) {
            return true;
        }
    }

    private void requestPermission(Activity activity) throws Exception {
        Method requestPermissions = Activity.class.getMethod("requestPermissions", String[].class, int.class);
        requestPermissions.invoke(activity, new Object[]{new String[]{POST_NOTIFICATIONS_PERMISSION}, REQUEST_CODE});
    }
}
