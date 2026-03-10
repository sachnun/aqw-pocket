package com.aqw.foreground;

import com.adobe.fre.FREContext;
import com.adobe.fre.FREExtension;

public class ForegroundExtension implements FREExtension {
    @Override
    public FREContext createContext(String extId) {
        return new ForegroundContext();
    }

    @Override
    public void initialize() {
    }

    @Override
    public void dispose() {
    }
}
