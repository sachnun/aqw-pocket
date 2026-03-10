package com.aqw.foreground;

import android.content.Context;
import android.content.Intent;

import com.adobe.fre.FREContext;
import com.adobe.fre.FREFunction;
import com.adobe.fre.FREObject;

import java.lang.reflect.Method;

public class StartServiceFunction implements FREFunction {
    @Override
    public FREObject call(FREContext context, FREObject[] args) {
        try {
            Context appContext = context.getActivity().getApplicationContext();
            Intent intent = new Intent(appContext, AqwForegroundService.class);
            intent.setAction(AqwForegroundService.ACTION_START);

            if (!startForegroundCompat(appContext, intent)) {
                appContext.startService(intent);
            }

            return FREObject.newObject(true);
        } catch (Exception e) {
            context.dispatchStatusEventAsync("FGS_ERROR", e.getMessage() != null ? e.getMessage() : "start failed");
            try {
                return FREObject.newObject(false);
            } catch (Exception ignored) {
                return null;
            }
        }
    }

    private boolean startForegroundCompat(Context context, Intent intent) {
        try {
            Method method = Context.class.getMethod("startForegroundService", Intent.class);
            method.invoke(context, intent);
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }
}
