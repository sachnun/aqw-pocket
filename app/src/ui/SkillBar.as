package ui {

	import flash.display.*;
	import flash.events.*;

	public class SkillBar extends Sprite {

		private static const BTN_LABELS:Array = ["1", "2", "3", "4", "5", "6"];
		private static const BTN_BASE:uint = 0x222222;
		private static const BTN_RIMS:Array = [0x888888, 0x888888, 0x888888, 0x888888, 0x888888, 0x888888];
		private static const BTN_SIZE:Number = 58;
		private static const BTN_GAP:Number = 10;

		public static const ORIGIN_X:Number = 706;
		public static const ORIGIN_Y:Number = 380;

		public function SkillBar(game:MovieClip) {
			this.game = game;
			build();
		}
		
		private var game:MovieClip;
		private var btns:Vector.<AttackButton> = new Vector.<AttackButton>();

		private function build():void {
			for (var i:int = 0; i < 6; i++) {
				const col:int = i % 3;
				const row:int = int(i / 3);

				const ab:AttackButton = new AttackButton(BTN_LABELS[i], BTN_BASE, uint(BTN_RIMS[i]), BTN_SIZE);
				ab.x = col * (BTN_SIZE + BTN_GAP);
				ab.y = row * (BTN_SIZE + BTN_GAP);

				ab.addEventListener(MouseEvent.MOUSE_DOWN, onPress);
				ab.addEventListener(MouseEvent.MOUSE_UP, onRelease);
				ab.addEventListener(MouseEvent.ROLL_OUT, onRelease);

				addChild(ab);
				btns.push(ab);
			}
		}

		private function onPress(e:MouseEvent):void {
			const btn:AttackButton = AttackButton(e.currentTarget);
			btn.setPressed(true);

			const idx:int = btns.indexOf(btn);
			if (idx < 0) return;

			try {
				const icon:* = game.ui.mcInterface.actBar.getChildByName("i" + (idx + 1));
				if (icon != null && icon.actObj != null) {
					if (icon.actObj.auto) game.world.approachTarget();
					else game.world.testAction(icon.actObj);
				}
			} catch (err:Error) {
			}
		}

		private function onRelease(e:MouseEvent):void {
			AttackButton(e.currentTarget).setPressed(false);
		}
	}
}

