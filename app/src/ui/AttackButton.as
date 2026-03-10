package ui {

	import flash.display.*;
	import flash.geom.*;
	import flash.text.*;

	public class AttackButton extends Sprite {

		public function AttackButton(lbl:String, color:uint, rim:uint, sz:Number, icon:DisplayObject = null, interactive:Boolean = true) {
			baseColor = color;
			rimColor = rim;
			size = sz;
			iconDisplay = icon;

			buttonMode = interactive;
			useHandCursor = interactive;
			mouseEnabled = interactive;

			bg = new Shape();

			addChild(bg);

			label = new TextField();
			label.selectable = false;
			label.mouseEnabled = false;
			label.width = size;
			label.height = size;
			label.y = size * 0.22;

			const fmt:TextFormat = new TextFormat("_sans", 18, 0xffffff, true, null, null, null, null, TextFormatAlign.CENTER);
			label.defaultTextFormat = fmt;
			label.text = lbl;

			addChild(label);

			if (iconDisplay != null) {
				if (iconDisplay is InteractiveObject) {
					InteractiveObject(iconDisplay).mouseEnabled = false;
				}
				iconDisplay.x = size * 0.5;
				iconDisplay.y = size * 0.5;
				addChild(iconDisplay);
				label.visible = false;
			}

			draw(false);
		}

		private var _pressed:Boolean = false;
		private var _toggled:Boolean = false;
		private var size:Number;
		private var baseColor:uint;
		private var rimColor:uint;
		private var bg:Shape;
		private var label:TextField;
		private var iconDisplay:DisplayObject;

		public function get toggled():Boolean {
			return _toggled;
		}

		public function setToggled(t:Boolean):void {
			_toggled = t;
			draw(_pressed);
		}

		public function setPressed(p:Boolean):void {
			if (_pressed == p) {
				return;
			}

			_pressed = p;

			draw(p);
		}

		private function draw(pressed:Boolean):void {
			const g:Graphics = bg.graphics;
			const lift:Number = pressed ? 0 : 3;
			const alpha:Number = 0.5;

			g.clear();

			if (!pressed) {
				g.beginFill(0x000000, 0.25);
				g.drawRoundRect(2, 5, size, size, 8);
				g.endFill();
			}

			const m:Matrix = new Matrix();
			m.createGradientBox(size, size, Math.PI * 0.6, 0, lift);

			const topC:uint = lerp(baseColor, 0xffffff, pressed ? 0.05 : 0.30);
			const botC:uint = lerp(baseColor, 0x000000, pressed ? 0.40 : 0.55);

			g.beginGradientFill(GradientType.LINEAR, [topC, baseColor, botC], [alpha, alpha, alpha], [0, 110, 255], m);
			g.drawRoundRect(0, lift, size, size, 8);
			g.endFill();

			const activeRim:uint = _toggled ? 0x44ff44 : rimColor;
			const rimAlpha:Number = _toggled ? 0.9 : (pressed ? 0.25 : 0.5);
			g.lineStyle(2, activeRim, rimAlpha);
			g.drawRoundRect(0, lift, size, size, 8);

			g.lineStyle(1, 0x000000, 0.25);
			g.drawRoundRect(2, lift + 2, size - 4, size - 4, 6);

			label.y = size * (pressed ? 0.26 : 0.22);
			label.textColor = _toggled ? 0x44ff44 : (pressed ? 0x999999 : 0xffffff);
			label.alpha = _toggled ? 0.9 : (pressed ? 0.4 : 0.5);

			if (iconDisplay != null) {
				iconDisplay.y = size * (pressed ? 0.53 : 0.50);
				iconDisplay.alpha = pressed ? 0.35 : 0.6;
			}
		}

		private function lerp(c:uint, t:uint, r:Number):uint {
			const rr:int = (c >> 16 & 0xff) + ((t >> 16 & 0xff) - (c >> 16 & 0xff)) * r;
			const gg:int = (c >> 8 & 0xff) + ((t >> 8 & 0xff) - (c >> 8 & 0xff)) * r;
			const bb:int = (c & 0xff) + ((t & 0xff) - (c & 0xff)) * r;
			return rr << 16 | gg << 8 | bb;
		}
	}
}
