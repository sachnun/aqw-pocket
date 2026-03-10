package ui {

	import flash.display.*;
	import flash.events.*;
	import flash.utils.Dictionary;
	import flash.utils.Timer;

	public class SkillBar extends Sprite {

		private static const BTN_BASE:uint = 0x222222;
		private static const BTN_RIM:uint = 0x888888;
		private static const BTN_EMPTY:uint = 0x1a1a1a;
		private static const BTN_SIZE:Number = 58;
		private static const BTN_GAP:Number = 10;

		private static const AUTO_INTERVAL_MS:int = 1000;

		public static const ORIGIN_X:Number = 638;
		public static const ORIGIN_Y:Number = 380;

		public function SkillBar(game:MovieClip) {
			this.game = game;
			autoTimer = new Timer(AUTO_INTERVAL_MS);
			autoTimer.addEventListener(TimerEvent.TIMER, onAutoTick);
			build();
		}
		
		private var game:MovieClip;
		private var btns:Vector.<AttackButton> = new Vector.<AttackButton>();
		private var skillByBtn:Dictionary = new Dictionary(true);
		private var btnBySkill:Object = {};
		private var autoBtn:AttackButton;
		private var autoActive:Boolean = false;
		private var autoTimer:Timer;
		private var autoSkillIndex:int = 0;
		private var autoSkillEnabled:Object = {};
		private var autoSkillOrder:Array = [1, 2, 3, 4, 5, 6];

		private function build():void {
			addSkillButton("1", 0, 0, 1);
			addEmptyButton(1, 0);

			autoBtn = new AttackButton("A", BTN_BASE, BTN_RIM, BTN_SIZE, null, true);
			autoBtn.x = 2 * (BTN_SIZE + BTN_GAP);
			autoBtn.y = 0;
			autoBtn.addEventListener(MouseEvent.MOUSE_DOWN, onAutoToggle);
			addChild(autoBtn);

			addSkillButton("6", 3, 0, 6);

			addSkillButton("2", 0, 1, 2);
			addSkillButton("3", 1, 1, 3);
			addSkillButton("4", 2, 1, 4);
			addSkillButton("5", 3, 1, 5);
		}

		private function addSkillButton(lbl:String, col:int, row:int, skillIdx:int, icon:DisplayObject = null):void {
			const ab:AttackButton = new AttackButton(lbl, BTN_BASE, BTN_RIM, BTN_SIZE, icon, true);
			ab.x = col * (BTN_SIZE + BTN_GAP);
			ab.y = row * (BTN_SIZE + BTN_GAP);

			ab.addEventListener(MouseEvent.MOUSE_DOWN, onPress);
			ab.addEventListener(MouseEvent.MOUSE_UP, onRelease);
			ab.addEventListener(MouseEvent.ROLL_OUT, onRelease);

			addChild(ab);
			btns.push(ab);
			skillByBtn[ab] = skillIdx;
			btnBySkill[skillIdx] = ab;
		}

		private function addEmptyButton(col:int, row:int):void {
			const ab:AttackButton = new AttackButton("", BTN_EMPTY, BTN_RIM, BTN_SIZE, null, false);
			ab.x = col * (BTN_SIZE + BTN_GAP);
			ab.y = row * (BTN_SIZE + BTN_GAP);
			addChild(ab);
		}

		private function onPress(e:MouseEvent):void {
			const btn:AttackButton = AttackButton(e.currentTarget);
			btn.setPressed(true);

			const idx:int = int(skillByBtn[btn]);
			if (idx <= 0) return;

			if (autoActive) {
				toggleAutoSkill(idx);
				return;
			}

			fireSkill(idx);
		}

		private function onRelease(e:MouseEvent):void {
			AttackButton(e.currentTarget).setPressed(false);
		}

		private function onAutoToggle(e:MouseEvent):void {
			autoActive = !autoActive;
			autoBtn.setToggled(autoActive);

			if (autoActive) {
				setAllAutoSkills(true);
				autoSkillIndex = 0;
				autoTimer.start();
			} else {
				autoTimer.stop();
				setAllAutoSkills(false);
			}
		}

		private function onAutoTick(e:TimerEvent):void {
			if (!autoActive) return;

			try { game.world.approachTarget(); } catch (e1:Error) {}

			const skills:Array = getEnabledAutoSkills();
			if (skills.length == 0) {
				return;
			}

			fireSkill(int(skills[autoSkillIndex % skills.length]));
			autoSkillIndex++;
		}

		private function toggleAutoSkill(idx:int):void {
			autoSkillEnabled[idx] = !(autoSkillEnabled[idx] === true);
			if (btnBySkill[idx] != null) {
				AttackButton(btnBySkill[idx]).setToggled(autoSkillEnabled[idx] === true);
			}
		}

		private function setAllAutoSkills(enabled:Boolean):void {
			for each (var idx:int in autoSkillOrder) {
				autoSkillEnabled[idx] = enabled;
				if (btnBySkill[idx] != null) {
					AttackButton(btnBySkill[idx]).setToggled(enabled);
				}
			}
		}

		private function getEnabledAutoSkills():Array {
			const result:Array = [];

			for each (var idx:int in autoSkillOrder) {
				if (autoSkillEnabled[idx] === true) {
					result.push(idx);
				}
			}

			return result;
		}

		private function fireSkill(idx:int):void {
			try {
				var icon:* = game.ui.mcInterface.actBar.getChildByName("i" + idx);
				if (icon != null && icon.actObj != null) {
					game.world.testAction(icon.actObj);
				}
			} catch (err:Error) {
			}
		}
	}
}
