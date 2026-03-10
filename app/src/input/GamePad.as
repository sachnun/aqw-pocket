package input {

	import flash.display.*;
	import flash.events.*;
	import flash.text.*;

	import ui.Layout;
	import ui.SkillBar;
	import bot.ui.BotPanel;
	import bot.ui.CellPanel;
	import bot.ui.MapIntelPanel;

	public class GamePad extends Sprite {

		private static const MENU_W:Number = 110;
		private static const MENU_ITH:Number = 26;
		private static const GEAR_SIZE:Number = 28;

		public function GamePad(game:MovieClip) {
			this.game = game;
			addEventListener(Event.ADDED_TO_STAGE, onAdded);
		}

		private var game:MovieClip;
		private var padContainer:Sprite;
		private var padVisible:Boolean = true;
		private var joystick:Joystick;

		private var walkCtrl:WalkController;
		private var skillBar:SkillBar;
		private var layout:Layout;
		private var botPanel:BotPanel;
		private var cellPanel:CellPanel;
		private var mapIntelPanel:MapIntelPanel;
		private var gearBtn:Sprite;
		private var dropdown:Sprite;
		private var dropdownOpen:Boolean = false;
		private var joystickActive:Boolean = false;

		private function buildGearMenu():void {
			gearBtn = new Sprite();

			drawPill(gearBtn.graphics, GEAR_SIZE, GEAR_SIZE);

			const gl:TextField = makeLabel("⚙", 0xffffff, 14, true);

			gl.width = GEAR_SIZE;
			gl.height = GEAR_SIZE;
			gl.y = 4;
			gl.alpha = 0.6;

			gearBtn.addChild(gl);
			gearBtn.x = 5;
			gearBtn.y = 5;
			gearBtn.buttonMode = true;
			gearBtn.useHandCursor = true;
			gearBtn.addEventListener(MouseEvent.CLICK, onGearClick);

			addChild(gearBtn);

			dropdown = new Sprite();
			dropdown.visible = false;

			const items:Array = [
				{
					label: "Hide UI",
					fn: doHideUI
				},
				{
					label: "Bot Panel",
					fn: doBotPanel
				},
				{
					label: "Cell Jump",
					fn: doCellJump
				},
				{
					label: "Map Intel",
					fn: doMapIntel
				},
				{
					label: "Edit Layout",
					fn: doEditLayout
				},
				{
					label: "Reset Layout",
					fn: doResetLayout
				}
			];

			const panelH:Number = items.length * MENU_ITH + 6;

			drawPill(dropdown.graphics, MENU_W, panelH, true);

			for (var i:int = 0; i < items.length; i++) {
				const row:Sprite = buildMenuItem(items[i].label, items[i].fn, i);
				dropdown.addChild(row);
			}

			dropdown.x = gearBtn.x;
			dropdown.y = gearBtn.y + GEAR_SIZE + 2;
			addChild(dropdown);
		}

		private function buildMenuItem(lbl:String, fn:Function, idx:int):Sprite {
			const row:Sprite = new Sprite();

			const hoverBg:Shape = new Shape();
			hoverBg.graphics.beginFill(0xffffff, 0.08);
			hoverBg.graphics.drawRoundRect(3, 0, MENU_W - 6, MENU_ITH, 4);
			hoverBg.graphics.endFill();
			hoverBg.visible = false;

			row.addChild(hoverBg);

			const tf:TextField = makeLabel(lbl, 0xffffff, 10, false);
			tf.width = MENU_W - 10;
			tf.height = MENU_ITH;
			tf.x = 5;
			tf.y = 6;
			tf.alpha = 0.6;

			const fmt:TextFormat = new TextFormat("_sans", 10, 0xffffff, false, null, null, null, null, TextFormatAlign.LEFT);
			tf.defaultTextFormat = fmt;
			tf.text = lbl;

			row.addChild(tf);

			row.y = 3 + idx * MENU_ITH;
			row.buttonMode = true;
			row.useHandCursor = true;

			row.addEventListener(MouseEvent.ROLL_OVER, function (e:MouseEvent):void {
				hoverBg.visible = true;
			});

			row.addEventListener(MouseEvent.ROLL_OUT, function (e:MouseEvent):void {
				hoverBg.visible = false;
			});

			row.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void {
				closeDropdown();
				fn();
				e.stopImmediatePropagation();
			});

			return row;
		}

		private function drawPill(g:Graphics, w:Number, h:Number, panel:Boolean = false):void {
			g.clear();
			g.beginFill(0x111111, 0.55);
			g.drawRoundRect(0, 0, w, h, panel ? 6 : 8);
			g.endFill();
			g.lineStyle(1, 0x888888, 0.4);
			g.drawRoundRect(0, 0, w, h, panel ? 6 : 8);
		}

		private function openDropdown():void {
			dropdownOpen = true;
			dropdown.visible = true;

			stage.addEventListener(MouseEvent.MOUSE_DOWN, onStageClickClose, false, 0, true);
		}

		private function closeDropdown():void {
			dropdownOpen = false;
			dropdown.visible = false;

			stage.removeEventListener(MouseEvent.MOUSE_DOWN, onStageClickClose);
		}

		private function doHideUI():void {
			padVisible = !padVisible;
			padContainer.visible = padVisible;

			const firstRow:Sprite = Sprite(dropdown.getChildAt(0));
			const tf:TextField = TextField(firstRow.getChildAt(1));

			tf.text = padVisible ? "Hide UI" : "Show UI";
		}

		private function doEditLayout():void {
			layout.toggleEdit();

			const row:Sprite = Sprite(dropdown.getChildAt(4));
			const tf:TextField = TextField(row.getChildAt(1));
			tf.text = layout.editMode ? "Save Layout" : "Edit Layout";
		}

		private function doResetLayout():void {
			layout.resetToDefaults();
		}

		private function doMapIntel():void {
			if (mapIntelPanel == null) {
				mapIntelPanel = new MapIntelPanel();
				mapIntelPanel.visible = false;
				addChild(mapIntelPanel);
			}
			mapIntelPanel.visible = !mapIntelPanel.visible;
			if (mapIntelPanel.visible) {
				mapIntelPanel.refresh();
			}
		}

		private function doBotPanel():void {
			if (botPanel == null) {
				botPanel = new BotPanel();
				botPanel.visible = false;
				addChild(botPanel);
			}
			botPanel.visible = !botPanel.visible;
		}

		private function doCellJump():void {
			if (cellPanel == null) {
				cellPanel = new CellPanel();
				cellPanel.visible = false;
				addChild(cellPanel);
			}
			cellPanel.visible = !cellPanel.visible;
			if (cellPanel.visible) {
				cellPanel.refresh();
			}
		}

		private function makeLabel(text:String, color:uint, size:int, bold:Boolean = false):TextField {
			const tf:TextField = new TextField();
			tf.selectable = false;
			tf.mouseEnabled = false;

			const fmt:TextFormat = new TextFormat("_sans", size, color, bold, null, null, null, null, TextFormatAlign.CENTER);
			tf.defaultTextFormat = fmt;
			tf.text = text;

			return tf;
		}

		private function onAdded(e:Event):void {
			removeEventListener(Event.ADDED_TO_STAGE, onAdded);

			padContainer = new Sprite();

			addChild(padContainer);

			joystick = new Joystick();
			walkCtrl = new WalkController(game, joystick);
			skillBar = new SkillBar(game);

			joystick.x = Joystick.DEFAULT_X;
			joystick.y = Joystick.DEFAULT_Y;
			skillBar.x = SkillBar.ORIGIN_X;
			skillBar.y = SkillBar.ORIGIN_Y;

			padContainer.addChild(joystick);
			padContainer.addChild(skillBar);

			layout = new Layout();
			layout.register("joystick", joystick, Joystick.DEFAULT_X, Joystick.DEFAULT_Y);
			layout.register("skillbar", skillBar, SkillBar.ORIGIN_X, SkillBar.ORIGIN_Y);
			layout.load();

			buildGearMenu();

			stage.addEventListener(MouseEvent.MOUSE_DOWN, onDown);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onMove);
			stage.addEventListener(MouseEvent.MOUSE_UP, onUp);
		}

		private function onGearClick(e:MouseEvent):void {
			if (dropdownOpen) {
				closeDropdown()
			} else {
				openDropdown();
			}

			e.stopImmediatePropagation();
		}


		private function onStageClickClose(e:MouseEvent):void {
			if (!dropdown.hitTestPoint(e.stageX, e.stageY) && !gearBtn.hitTestPoint(e.stageX, e.stageY)) {
				closeDropdown();
			}
		}

		private function onDown(e:MouseEvent):void {
			if (!padVisible || layout.editMode) {
				return;
			}

			if (joystick.hitTest(e.stageX, e.stageY)) {
				joystickActive = true;
				joystick.move(e.stageX, e.stageY);
				stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			}
		}

		private function onMove(e:MouseEvent):void {
			if (joystickActive) {
				joystick.move(e.stageX, e.stageY);
			}
		}

		private function onUp(e:MouseEvent):void {
			if (!joystickActive) {
				return;
			}

			joystickActive = false;

			joystick.snapHome();

			stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);

			walkCtrl.stop();
		}

		private function onEnterFrame(e:Event):void {
			walkCtrl.update();
		}

	}
}
