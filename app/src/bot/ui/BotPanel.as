package bot.ui {

	import flash.display.*;
	import flash.events.*;
	import flash.text.*;

	import bot.BotController;
	import bot.GameAccessor;

	/**
	 * BotPanel - on-screen control panel for bot operations.
	 * Displayed as a draggable overlay on top of the game.
	 * Toggled from the GamePad gear menu.
	 */
	public class BotPanel extends Sprite {

		private static const PANEL_W:Number = 280;
		private static const PANEL_H:Number = 400;
		private static const HEADER_H:Number = 28;
		private static const ROW_H:Number = 30;
		private static const BTN_H:Number = 26;
		private static const MARGIN:Number = 8;
		private static const COL_BG:uint = 0x111111;
		private static const COL_HEADER:uint = 0x1a1a1a;
		private static const COL_BTN:uint = 0x2a2a2a;
		private static const COL_BTN_ACTIVE:uint = 0x1a5a1a;
		private static const COL_RIM:uint = 0x555555;
		private static const COL_TEXT:uint = 0xcccccc;
		private static const COL_ACCENT:uint = 0x44cc44;

		private var bg:Shape;
		private var headerBar:Sprite;
		private var content:Sprite;
		private var dragging:Boolean = false;
		private var dragOffX:Number;
		private var dragOffY:Number;

		// UI elements that need updating
		private var hidePlayersBtn:Sprite;
		private var hidePlayersLabel:TextField;
		private var disableCollBtn:Sprite;
		private var disableCollLabel:TextField;
		private var killLagBtn:Sprite;
		private var killLagLabel:TextField;
		private var killLagEnabled:Boolean = false;
		private var spawnInPlaceBtn:Sprite;
		private var spawnInPlaceLabel:TextField;

		// Spawn-in-place state (runs directly here since module onFrame doesn't fire)
		private var _sipSavedCell:String = "";
		private var _sipSavedPad:String = "Left";
		private var _sipDead:Boolean = false;

		public function BotPanel() {
			buildPanel();
			this.x = 340;
			this.y = 60;
		}

		private function buildPanel():void {
			// Background
			bg = new Shape();
			drawBackground();
			addChild(bg);

			// Header (draggable)
			headerBar = new Sprite();
			headerBar.graphics.beginFill(COL_HEADER, 0.95);
			headerBar.graphics.drawRoundRect(0, 0, PANEL_W, HEADER_H, 6, 6);
			headerBar.graphics.endFill();

			var title:TextField = makeLabel("Bot Panel", COL_ACCENT, 11, true);
			title.x = MARGIN;
			title.y = 5;
			title.width = PANEL_W - 60;
			headerBar.addChild(title);

			// Close button
			var closeBtn:Sprite = new Sprite();
			closeBtn.graphics.beginFill(0x882222, 0.8);
			closeBtn.graphics.drawRoundRect(0, 0, 22, 20, 4);
			closeBtn.graphics.endFill();
			var closeLbl:TextField = makeLabel("X", 0xffffff, 10, true);
			closeLbl.width = 22;
			closeLbl.y = 2;
			closeBtn.addChild(closeLbl);
			closeBtn.x = PANEL_W - 30;
			closeBtn.y = 4;
			closeBtn.buttonMode = true;
			closeBtn.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void {
				visible = false;
				e.stopImmediatePropagation();
			});
			headerBar.addChild(closeBtn);

			headerBar.buttonMode = true;
			headerBar.addEventListener(MouseEvent.MOUSE_DOWN, onStartDrag);
			addChild(headerBar);

			// Content area
			content = new Sprite();
			content.y = HEADER_H + 4;
			addChild(content);

			var yOff:Number = 0;

			// --- Section: Modules ---
			yOff = addSectionHeader("MODULES", yOff);

			var halfW:Number = (PANEL_W - MARGIN * 2 - 4) / 2;

			var hpResult:Object = makeToggleButton("Hide Players", halfW, function ():void {
				BotController.toggleHidePlayers();
				updateModuleBtns();
			});
			hidePlayersBtn = hpResult.btn;
			hidePlayersLabel = hpResult.label;
			hidePlayersBtn.x = MARGIN;
			hidePlayersBtn.y = yOff;
			content.addChild(hidePlayersBtn);

			var dcResult:Object = makeToggleButton("No Collision", halfW, function ():void {
				BotController.toggleDisableCollisions();
				updateModuleBtns();
			});
			disableCollBtn = dcResult.btn;
			disableCollLabel = dcResult.label;
			disableCollBtn.x = MARGIN + halfW + 4;
			disableCollBtn.y = yOff;
			content.addChild(disableCollBtn);
			yOff += ROW_H + 2;

			var klResult:Object = makeToggleButton("Kill Lag", halfW, function ():void {
				killLagEnabled = !killLagEnabled;
				BotController.toggleKillLag(killLagEnabled);
				updateModuleBtns();
			});
			killLagBtn = klResult.btn;
			killLagLabel = klResult.label;
			killLagBtn.x = MARGIN;
			killLagBtn.y = yOff;
			content.addChild(killLagBtn);

			var sipResult:Object = makeToggleButton("Spawn In Cell", halfW, function ():void {
				BotController.toggleSpawnInPlace();
				updateModuleBtns();
			});
			spawnInPlaceBtn = sipResult.btn;
			spawnInPlaceLabel = sipResult.label;
			spawnInPlaceBtn.x = MARGIN + halfW + 4;
			spawnInPlaceBtn.y = yOff;
			content.addChild(spawnInPlaceBtn);
			yOff += ROW_H + 6;

			// Update debug label every frame
			addEventListener(Event.ENTER_FRAME, onFrameUpdate);

			// Resize background to fit
			drawBackgroundWithHeight(HEADER_H + yOff + 10);
		}

		private function updateModuleBtns():void {
			var halfW:Number = (PANEL_W - MARGIN * 2 - 4) / 2;

			var hp:Boolean = BotController.isHidePlayersEnabled();
			hidePlayersLabel.textColor = hp ? COL_ACCENT : COL_TEXT;
			drawBtnBg(hidePlayersBtn, halfW, hp ? COL_BTN_ACTIVE : COL_BTN);

			var dc:Boolean = BotController.isDisableCollisionsEnabled();
			disableCollLabel.textColor = dc ? COL_ACCENT : COL_TEXT;
			drawBtnBg(disableCollBtn, halfW, dc ? COL_BTN_ACTIVE : COL_BTN);

			killLagLabel.textColor = killLagEnabled ? COL_ACCENT : COL_TEXT;
			drawBtnBg(killLagBtn, halfW, killLagEnabled ? COL_BTN_ACTIVE : COL_BTN);

			var sip:Boolean = BotController.isSpawnInPlaceEnabled();
			spawnInPlaceLabel.textColor = sip ? COL_ACCENT : COL_TEXT;
			drawBtnBg(spawnInPlaceBtn, halfW, sip ? COL_BTN_ACTIVE : COL_BTN);
		}

		// ==========================================
		// Frame update for spawn-in-place logic
		// ==========================================

		private function onFrameUpdate(e:Event):void {
			var sipOn:Boolean = BotController.isSpawnInPlaceEnabled();
			if (!sipOn) {
				if (_sipDead) _sipDead = false;
				if (_sipSavedCell != "") _sipSavedCell = "";
				return;
			}

			try {
				var game:* = GameAccessor.game;
				if (game == null || game.world == null || game.world.myAvatar == null) return;

				var dl:* = game.world.myAvatar.dataLeaf;
				if (dl == null) return;

				var hp:int = int(dl.intHP);
				var cell:String = String(game.world.strFrame || "");
				var pad:String = String(game.world.strPad || "Left");

				if (hp > 0) {
					// Alive: save current cell and set spawn point
					if (cell != "" && cell != "Blank") {
						_sipSavedCell = cell;
						_sipSavedPad = pad;
						try {
							game.world.setSpawnPoint(cell, pad);
						} catch (spErr:Error) {}
					}

					if (_sipDead) {
						// Just respawned — jump back if server moved us
						_sipDead = false;
						if (_sipSavedCell != "" && cell != _sipSavedCell && cell != "Blank") {
							try {
								game.world.moveToCell(_sipSavedCell, _sipSavedPad);
							} catch (mvErr:Error) {}
						}
					}
				} else if (!_sipDead) {
					// Just died
					_sipDead = true;
				}
			} catch (err:Error) {}
		}

		// ==========================================
		// UI Helpers
		// ==========================================

		private function addSectionHeader(text:String, yOff:Number):Number {
			var header:TextField = makeLabel(text, 0x888888, 9, true);
			header.x = MARGIN;
			header.y = yOff;
			header.width = PANEL_W - MARGIN * 2;
			content.addChild(header);
			return yOff + 18;
		}

		private function makeToggleButton(label:String, w:Number, onClick:Function):Object {
			var btn:Sprite = new Sprite();
			drawBtnBg(btn, w, COL_BTN);

			var tf:TextField = makeLabel(label, COL_TEXT, 10, false);
			tf.width = w;
			tf.height = BTN_H;
			tf.y = 5;
			btn.addChild(tf);

			btn.buttonMode = true;
			btn.useHandCursor = true;
			btn.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void {
				onClick();
				e.stopImmediatePropagation();
			});
			return {btn: btn, label: tf};
		}

		private function drawBtnBg(btn:Sprite, w:Number, color:uint):void {
			var g:Graphics = btn.graphics;
			g.clear();
			g.beginFill(color, 0.85);
			g.drawRoundRect(0, 0, w, BTN_H, 4);
			g.endFill();
			g.lineStyle(1, COL_RIM, 0.4);
			g.drawRoundRect(0, 0, w, BTN_H, 4);
		}

		private function drawBackground():void {
			drawBackgroundWithHeight(PANEL_H);
		}

		private function drawBackgroundWithHeight(h:Number):void {
			var g:Graphics = bg.graphics;
			g.clear();
			g.beginFill(COL_BG, 0.92);
			g.drawRoundRect(0, 0, PANEL_W, h, 8);
			g.endFill();
			g.lineStyle(1, COL_RIM, 0.5);
			g.drawRoundRect(0, 0, PANEL_W, h, 8);
		}

		private function makeLabel(text:String, color:uint, size:int, bold:Boolean):TextField {
			var tf:TextField = new TextField();
			tf.selectable = false;
			tf.mouseEnabled = false;
			var fmt:TextFormat = new TextFormat("_sans", size, color, bold, null, null, null, null, TextFormatAlign.CENTER);
			tf.defaultTextFormat = fmt;
			tf.text = text;
			return tf;
		}

		// Drag handling
		private function onStartDrag(e:MouseEvent):void {
			dragging = true;
			dragOffX = e.stageX - this.x;
			dragOffY = e.stageY - this.y;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onDrag);
			stage.addEventListener(MouseEvent.MOUSE_UP, onStopDrag);
			e.stopImmediatePropagation();
		}

		private function onDrag(e:MouseEvent):void {
			if (!dragging) return;
			this.x = e.stageX - dragOffX;
			this.y = e.stageY - dragOffY;
		}

		private function onStopDrag(e:MouseEvent):void {
			dragging = false;
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDrag);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onStopDrag);
		}
	}
}
