package core {
    import flash.events.StatusEvent;
    import flash.external.ExtensionContext;

    public class ForegroundService {
        private static const EXT_ID:String = "com.aqw.foreground";
        private var ctx:ExtensionContext;

        public function ForegroundService() {
            ctx = ExtensionContext.createExtensionContext(EXT_ID, null);
            if (ctx != null) {
                ctx.addEventListener(StatusEvent.STATUS, onStatus);
            }
        }

        public function start():Boolean {
            if (ctx == null) {
                return false;
            }
            return Boolean(ctx.call("startService"));
        }

        public function requestNotificationPermission():Boolean {
            if (ctx == null) {
                return false;
            }
            return Boolean(ctx.call("requestNotificationPermission"));
        }

        public function stop():Boolean {
            if (ctx == null) {
                return false;
            }
            return Boolean(ctx.call("stopService"));
        }

        public function showToast(message:String):Boolean {
            if (ctx == null) {
                return false;
            }
            return Boolean(ctx.call("showToast", message));
        }

        public function dispose():void {
            if (ctx != null) {
                ctx.removeEventListener(StatusEvent.STATUS, onStatus);
                ctx.dispose();
                ctx = null;
            }
        }

        private function onStatus(e:StatusEvent):void {
        }
    }
}
