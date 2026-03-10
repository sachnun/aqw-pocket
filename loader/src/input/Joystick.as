package input {
	import flash.display.*;
	import flash.geom.*;

	public class Joystick extends Sprite {

		public static const RADIUS:Number = 72;
		public static const KNOB_RADIUS:Number = 28;
		public static const LIMIT:Number = RADIUS - KNOB_RADIUS * 0.4;

		public static const DEFAULT_X:Number = 73;
		public static const DEFAULT_Y:Number = 348;

		public function Joystick() {
			buildBase();
			buildDirectionTicks();
			buildKnob();
		}

		public var dirX:Number = 0;
		public var dirY:Number = 0;
		private var knob:Shape;

		public function move(stageX:Number, stageY:Number):void {
			const local:Point = globalToLocal(new Point(stageX, stageY));
			var dx:Number = local.x;
			var dy:Number = local.y;

			const dist:Number = Math.sqrt(dx * dx + dy * dy);

			if (dist > LIMIT) {
				dx = dx / dist * LIMIT;
				dy = dy / dist * LIMIT;
			}

			knob.x = dx;
			knob.y = dy;

			dirX = dx / LIMIT;
			dirY = dy / LIMIT;
		}

		public function snapHome():void {
			knob.x = 0;
			knob.y = 0;
			dirX = 0;
			dirY = 0;
		}

		public function hitTest(stageX:Number, stageY:Number):Boolean {
			const local:Point = globalToLocal(new Point(stageX, stageY));
			return Math.sqrt(local.x * local.x + local.y * local.y) <= RADIUS + 20;
		}


		private function buildBase():void {
			const base:Shape = new Shape();
			const g:Graphics = base.graphics;

			// Soft outer glow
			const mGlow:Matrix = new Matrix();
			mGlow.createGradientBox((RADIUS + 14) * 2, (RADIUS + 14) * 2, 0, -(RADIUS + 14), -(RADIUS + 14));
			g.beginGradientFill(GradientType.RADIAL, [0x444444, 0x000000], [0.15, 0], [160, 255], mGlow);
			g.drawCircle(0, 0, RADIUS + 14);
			g.endFill();

			// Base fill — dark grey, 50% alpha
			const mBase:Matrix = new Matrix();
			mBase.createGradientBox(RADIUS * 2, RADIUS * 2, Math.PI / 2, -RADIUS, -RADIUS);
			g.beginGradientFill(GradientType.RADIAL, [0x555555, 0x111111], [0.5, 0.5], [55, 255], mBase);
			g.drawCircle(0, 0, RADIUS);
			g.endFill();

			// Outer rim
			g.lineStyle(2, 0x888888, 0.5);
			g.drawCircle(0, 0, RADIUS);

			// Inner guide ring
			g.lineStyle(1, 0x666666, 0.25);
			g.drawCircle(0, 0, RADIUS * 0.52);

			addChild(base);
		}

		private function buildDirectionTicks():void {
			const ticks:Shape = new Shape();
			const g:Graphics = ticks.graphics;

			for each (var a:Number in [0, 90, 180, 270]) {
				const rad:Number = a * Math.PI / 180;

				g.lineStyle(1.5, 0x888888, 0.25);
				g.moveTo(Math.cos(rad) * RADIUS * 0.58, Math.sin(rad) * RADIUS * 0.58);
				g.lineTo(Math.cos(rad) * RADIUS * 0.82, Math.sin(rad) * RADIUS * 0.82);
			}

			addChild(ticks);
		}

		private function buildKnob():void {
			knob = new Shape();

			redrawKnob();

			knob.x = 0;
			knob.y = 0;

			addChild(knob);
		}

		private function redrawKnob():void {
			const g:Graphics = knob.graphics;
			g.clear();

			// Shadow
			const mSh:Matrix = new Matrix();
			mSh.createGradientBox((KNOB_RADIUS + 4) * 2, (KNOB_RADIUS + 4) * 2, 0, -(KNOB_RADIUS + 4), -KNOB_RADIUS + 5);
			g.beginGradientFill(GradientType.RADIAL, [0x000000, 0x000000], [0.25, 0], [90, 255], mSh);
			g.drawCircle(0, 5, KNOB_RADIUS + 4);
			g.endFill();

			// Body — grey, 50% alpha
			const m:Matrix = new Matrix();
			m.createGradientBox(KNOB_RADIUS * 2, KNOB_RADIUS * 2, -Math.PI * 0.3, -KNOB_RADIUS, -KNOB_RADIUS);
			g.beginGradientFill(GradientType.RADIAL, [0x777777, 0x444444, 0x111111], [0.5, 0.5, 0.5], [35, 155, 255], m);
			g.drawCircle(0, 0, KNOB_RADIUS);
			g.endFill();

			// Rim
			g.lineStyle(1.5, 0x888888, 0.5);
			g.drawCircle(0, 0, KNOB_RADIUS);

			// Centre pip
			g.beginFill(0x222222, 0.5);
			g.drawCircle(0, 0, 4.5);
			g.endFill();
		}

	}
}
