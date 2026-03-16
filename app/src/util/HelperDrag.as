package util {

	import flash.display.Sprite;
	import flash.events.MouseEvent;

	public class HelperDrag {

		public function HelperDrag(target:Sprite, drag:Sprite, callback:Function = null):void {
			this.target = target;
			this.drag = drag;
			this.callback = callback;

			this.drag.mouseEnabled = true;
			this.drag.mouseChildren = false;
			this.drag.useHandCursor = true;
			this.drag.buttonMode = true;

			this.drag.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 0, true);
			this.drag.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 0, true);
		}

		public var drag:Sprite;
		public var target:Sprite;
		public var callback:Function;

		public function destroy():void {
			this.drag.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			this.drag.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);

			this.target.stopDrag();
		}

		private function onMouseDown(e:MouseEvent):void {
			this.target.startDrag(false);
		}

		private function onMouseUp(e:MouseEvent):void {
			this.target.stopDrag();

			if (this.callback != null) {
				this.callback();
			}
		}

	}
}
