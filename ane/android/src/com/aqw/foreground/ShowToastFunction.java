package com.aqw.foreground;

import android.widget.Toast;

import com.adobe.fre.FREContext;
import com.adobe.fre.FREFunction;
import com.adobe.fre.FREObject;

public class ShowToastFunction implements FREFunction {
    @Override
    public FREObject call(final FREContext context, FREObject[] args) {
        try {
            final String message = args != null && args.length > 0 && args[0] != null
                    ? args[0].getAsString()
                    : "Tekan sekali lagi untuk keluar";

            context.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    Toast.makeText(context.getActivity(), message, Toast.LENGTH_SHORT).show();
                }
            });

            return FREObject.newObject(true);
        } catch (Exception e) {
            context.dispatchStatusEventAsync("FGS_ERROR", e.getMessage() != null ? e.getMessage() : "toast failed");
            try {
                return FREObject.newObject(false);
            } catch (Exception ignored) {
                return null;
            }
        }
    }
}
