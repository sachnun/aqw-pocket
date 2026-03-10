package com.aqw.foreground;

import com.adobe.fre.FREContext;
import com.adobe.fre.FREFunction;

import java.util.HashMap;
import java.util.Map;

public class ForegroundContext extends FREContext {
    @Override
    public void dispose() {
    }

    @Override
    public Map<String, FREFunction> getFunctions() {
        Map<String, FREFunction> functions = new HashMap<>();
        functions.put("requestNotificationPermission", new RequestNotificationPermissionFunction());
        functions.put("startService", new StartServiceFunction());
        functions.put("stopService", new StopServiceFunction());
        functions.put("showToast", new ShowToastFunction());
        return functions;
    }
}
