package com.aqw.foreground;

import android.content.Context;
import android.content.Intent;

import com.adobe.fre.FREContext;
import com.adobe.fre.FREFunction;
import com.adobe.fre.FREObject;

public class StopServiceFunction implements FREFunction {
    @Override
    public FREObject call(FREContext context, FREObject[] args) {
        try {
            Context appContext = context.getActivity().getApplicationContext();
            AqwForegroundService.disablePersistentNotification();
            Intent intent = new Intent(appContext, AqwForegroundService.class);
            appContext.stopService(intent);
            return FREObject.newObject(true);
        } catch (Exception e) {
            context.dispatchStatusEventAsync("FGS_ERROR", e.getMessage() != null ? e.getMessage() : "stop failed");
            try {
                return FREObject.newObject(false);
            } catch (Exception ignored) {
                return null;
            }
        }
    }
}
