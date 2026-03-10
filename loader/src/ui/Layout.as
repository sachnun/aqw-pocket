package ui {

	import flash.display.*;
	import flash.events.*;
	import flash.geom.*;
	import flash.net.SharedObject;

	public class Layout extends EventDispatcher {

		private static const SAVE_KEY:String = "aqw_mobile_layout";
		private static const HANDLE_SIZE:uint = 28;

		public function Layout() {
			so = SharedObject.getLocal(SAVE_KEY);
		}

		private var so:SharedObject;
		private var widgets:Vector.<WidgetEntry> = new Vector.<WidgetEntry>();
		private var dragging:WidgetEntry;
		private var dragOffX:Number;
		private var dragOffY:Number;

		private var _editMode:Boolean = false;

		public function get editMode():Boolean {
			return _editMode;
		}

		public function register(id:String, target:DisplayObject, defaultX:Number, defaultY:Number):void {
			widgets.push(new WidgetEntry(id, target, defaultX, defaultY));
		}

		public function load():void {
			for each (var e:WidgetEntry in widgets) {
				const saved:Object = so.data[e.id];

				e.target.x = saved ? saved.x : e.defaultX;
				e.target.y = saved ? saved.y : e.defaultY;
			}
		}

		public function toggleEdit():void {
			_editMode = !_editMode;

			for each (var e:WidgetEntry in widgets) {
				if (_editMode) {
					showHandle(e);
					continue;
				}

				hideHandle(e);
				saveAll();
			}
		}

		public function resetToDefaults():void {
			if (_editMode) {
				for each (var e:WidgetEntry in widgets) {
					hideHandle(e);
				}

				_editMode = false;
			}

			for each (var entry:WidgetEntry in widgets) {
				entry.target.x = entry.defaultX;
				entry.target.y = entry.defaultY;

				delete so.data[entry.id];
			}

			so.flush();
		}


		private function showHandle(e:WidgetEntry):void {
			if (e.handle != null) {
				return;
			}

			const h:Sprite = new Sprite();

			drawHandle(h.graphics);

			h.x = e.target.x;
			h.y = e.target.y;
			h.buttonMode = true;
			h.useHandCursor = true;

			e.target.parent.addChild(h);

			h.addEventListener(MouseEvent.MOUSE_DOWN, onHandleDown);
			h.addEventListener(MouseEvent.ROLL_OVER, onHandleOver);
			h.addEventListener(MouseEvent.ROLL_OUT, onHandleOut);

			e.handle = h;
		}

		private function hideHandle(e:WidgetEntry):void {
			if (e.handle == null) {
				return;
			}

			e.handle.removeEventListener(MouseEvent.MOUSE_DOWN, onHandleDown);
			e.handle.removeEventListener(MouseEvent.ROLL_OVER, onHandleOver);
			e.handle.removeEventListener(MouseEvent.ROLL_OUT, onHandleOut);

			if (e.handle.parent) {
				e.handle.parent.removeChild(e.handle);
			}

			e.handle = null;
		}

		private function drawHandle(g:Graphics, hover:Boolean = false):void {
			g.clear();
			g.beginFill(0x000000, hover ? 0.70 : 0.50);
			g.drawRoundRect(0, 0, HANDLE_SIZE, HANDLE_SIZE, 6);
			g.endFill();
			g.lineStyle(1.5, 0xffffff, hover ? 0.80 : 0.50);
			g.drawRoundRect(0, 0, HANDLE_SIZE, HANDLE_SIZE, 6);

			const cx:Number = HANDLE_SIZE / 2, cy:Number = HANDLE_SIZE / 2, arm:Number = 7;

			g.moveTo(cx, cy - arm);
			g.lineTo(cx, cy + arm);
			g.moveTo(cx - arm, cy);
			g.lineTo(cx + arm, cy);
			g.moveTo(cx - 3, cy - arm);
			g.lineTo(cx, cy - arm - 4);
			g.lineTo(cx + 3, cy - arm);
			g.moveTo(cx - 3, cy + arm);
			g.lineTo(cx, cy + arm + 4);
			g.lineTo(cx + 3, cy + arm);
			g.moveTo(cx - arm, cy - 3);
			g.lineTo(cx - arm - 4, cy);
			g.lineTo(cx - arm, cy + 3);
			g.moveTo(cx + arm, cy - 3);
			g.lineTo(cx + arm + 4, cy);
			g.lineTo(cx + arm, cy + 3);
		}

		private function saveAll():void {
			for each (var e:WidgetEntry in widgets) {
				so.data[e.id] = {
					x: e.target.x,
					y: e.target.y
				};
			}

			so.flush();
		}

		private function entryForHandle(h:Sprite):WidgetEntry {
			for each (var e:WidgetEntry in widgets) {
				if (e.handle == h) {
					return e;
				}
			}

			return null;
		}

		private function onHandleDown(e:MouseEvent):void {
			const h:Sprite = Sprite(e.currentTarget);

			dragging = entryForHandle(h);

			if (dragging == null) {
				return;
			}

			dragOffX = h.parent.mouseX - dragging.target.x;
			dragOffY = h.parent.mouseY - dragging.target.y;

			h.stage.addEventListener(MouseEvent.MOUSE_MOVE, onDragMove);
			h.stage.addEventListener(MouseEvent.MOUSE_UP, onDragUp);

			e.stopImmediatePropagation();
		}

		private function onDragMove(e:MouseEvent):void {
			if (dragging == null) {
				return;
			}

			const pt:Point = dragging.target.parent.globalToLocal(new Point(e.stageX, e.stageY));

			dragging.target.x = pt.x - dragOffX;
			dragging.target.y = pt.y - dragOffY;
			dragging.handle.x = dragging.target.x;
			dragging.handle.y = dragging.target.y;
		}

		private function onDragUp(e:MouseEvent):void {
			if (dragging == null) {
				return;
			}

			dragging.handle.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDragMove);
			dragging.handle.stage.removeEventListener(MouseEvent.MOUSE_UP, onDragUp);
			
			dragging = null;
		}

		private function onHandleOver(e:MouseEvent):void {
			drawHandle(Sprite(e.currentTarget).graphics, true);
		}

		private function onHandleOut(e:MouseEvent):void {
			drawHandle(Sprite(e.currentTarget).graphics, false);
		}

	}
}