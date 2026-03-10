package bot.ui {

	import flash.display.*;
	import flash.events.*;
	import flash.text.*;

	import bot.api.PlayerAPI;
	import bot.api.WorldAPI;

	/**
	 * CellPanel - on-screen panel for cell navigation within the current map.
	 * Tap a cell to instantly jump there (always uses Spawn pad).
	 * The player's current cell is auto-highlighted.
	 * Cell list auto-refreshes when the map changes.
	 */
	public class CellPanel extends Sprite {

		private static const PANEL_W:Number = 280;
		private static const HEADER_H:Number = 28;
		private static const MARGIN:Number = 8;
		private static const BTN_H:Number = 26;
		private static const COL_BG:uint = 0x111111;
		private static const COL_HEADER:uint = 0x1a1a1a;
		private static const COL_BTN:uint = 0x2a2a2a;
		private static const COL_BTN_CUR:uint = 0x1a5a1a;
		private static const COL_RIM:uint = 0x555555;
		private static const COL_TEXT:uint = 0xcccccc;
		private static const COL_ACCENT:uint = 0x44cc44;
		private static const CELL_AREA_H:Number = 140;

		private var bg:Shape;
		private var headerBar:Sprite;
		private var content:Sprite;
		private var cellContainer:Sprite;
		private var cellMask:Shape;
		private var cellScrollArea:Sprite;

		private var statusField:TextField;

		private var cellButtons:Array = [];

		private var dragging:Boolean = false;
		private var dragOffX:Number;
		private var dragOffY:Number;

		private var scrollOffset:Number = 0;
		private var maxScroll:Number = 0;

		// Touch-scroll state
		private var touchScrolling:Boolean = false;
		private var touchStartY:Number = 0;
		private var scrollStartOffset:Number = 0;

		// Auto-refresh: track current map name
		private var lastMapName:String = "";
		// Auto-mark: track current cell
		private var lastPlayerCell:String = "";

		public function CellPanel() {
			buildPanel();
			this.x = 50;
			this.y = 60;
		}

		/** Refresh cell list and current status display */
		public function refresh():void {
			lastMapName = WorldAPI.getMapName();
			lastPlayerCell = "";
			populateCells();
			updateCurrentDisplay();
			autoMarkCurrentCell();
		}

		private function buildPanel():void {
			bg = new Shape();
			addChild(bg);

			// ---- Header (draggable) ----
			headerBar = new Sprite();
			headerBar.graphics.beginFill(COL_HEADER, 0.95);
			headerBar.graphics.drawRoundRect(0, 0, PANEL_W, HEADER_H, 6, 6);
			headerBar.graphics.endFill();

			var title:TextField = makeLabel("Cell Jump", COL_ACCENT, 11, true);
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
			closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				visible = false;
				e.stopImmediatePropagation();
			});
			headerBar.addChild(closeBtn);

			headerBar.buttonMode = true;
			headerBar.addEventListener(MouseEvent.MOUSE_DOWN, onStartDrag);
			addChild(headerBar);

			// ---- Content area ----
			content = new Sprite();
			content.y = HEADER_H + 4;
			addChild(content);

			var yOff:Number = 0;

			// Current cell status
			statusField = makeLabel("- / -", COL_TEXT, 9, false);
			statusField.width = PANEL_W - MARGIN * 2;
			statusField.x = MARGIN;
			statusField.y = yOff;
			content.addChild(statusField);
			yOff += 20;

			// ---- Section: CELLS ----
			yOff = addSectionHeader("CELLS", yOff);

			// Scrollable cell list area
			cellScrollArea = new Sprite();
			cellScrollArea.x = MARGIN;
			cellScrollArea.y = yOff;
			content.addChild(cellScrollArea);

			cellContainer = new Sprite();
			cellScrollArea.addChild(cellContainer);

			cellMask = new Shape();
			cellMask.graphics.beginFill(0x000000);
			cellMask.graphics.drawRect(0, 0, PANEL_W - MARGIN * 2, CELL_AREA_H);
			cellMask.graphics.endFill();
			cellScrollArea.addChild(cellMask);
			cellContainer.mask = cellMask;

			// Mouse wheel scroll
			cellScrollArea.addEventListener(MouseEvent.MOUSE_WHEEL, onCellWheel);
			// Touch scroll
			cellScrollArea.addEventListener(MouseEvent.MOUSE_DOWN, onCellTouchDown);

			yOff += CELL_AREA_H + 6;

			drawBackgroundWithHeight(HEADER_H + yOff + 10);

			// Frame listener for live status + auto-refresh + auto-mark
			addEventListener(Event.ENTER_FRAME, onFrame);
		}

		// ==========================================
		// Logic
		// ==========================================

		private function onFrame(e:Event):void {
			if (!visible) return;
			updateCurrentDisplay();
			checkMapChange();
			autoMarkCurrentCell();
		}

		/** Detect map change and auto-refresh cell list */
		private function checkMapChange():void {
			var currentMap:String = WorldAPI.getMapName();
			if (currentMap.length > 0 && currentMap != lastMapName) {
				// Only commit the map change if cells are available (map SWF fully loaded).
				// If getCells() returns empty, the map is still loading - retry next frame.
				var cells:Array = WorldAPI.getCells();
				if (cells.length > 0) {
					lastMapName = currentMap;
					lastPlayerCell = "";
					populateCells();
				}
			}
		}

		/** Auto-highlight the cell the player is currently in */
		private function autoMarkCurrentCell():void {
			var curCell:String = PlayerAPI.getCurrentCell();
			if (curCell == lastPlayerCell) return;
			lastPlayerCell = curCell;

			var btnW:Number = (PANEL_W - MARGIN * 2 - 8) / 3;
			for (var i:int = 0; i < cellButtons.length; i++) {
				var item:Object = cellButtons[i];
				var isCur:Boolean = (item.name == curCell);
				drawBtnBg(item.btn, btnW, isCur ? COL_BTN_CUR : COL_BTN);
				item.label.textColor = isCur ? COL_ACCENT : COL_TEXT;
			}
		}

		private function updateCurrentDisplay():void {
			try {
				var cell:String = PlayerAPI.getCurrentCell();
				var mapName:String = WorldAPI.getMapName();
				statusField.text = mapName + "  |  " + cell;
			} catch (err:Error) {
				statusField.text = "- / -";
			}
		}

		private function populateCells():void {
			// Clear existing cell buttons
			while (cellContainer.numChildren > 0) {
				cellContainer.removeChildAt(0);
			}
			cellButtons = [];
			scrollOffset = 0;
			cellContainer.y = 0;

			var cells:Array = WorldAPI.getCells();
			if (cells.length == 0) return;

			var btnW:Number = (PANEL_W - MARGIN * 2 - 8) / 3;
			var yPos:Number = 0;

			for (var i:int = 0; i < cells.length; i++) {
				var col:int = i % 3;
				var row:int = int(i / 3);

				var cellName:String = cells[i];
				var cellResult:Object = makeCellButton(cellName, btnW);
				cellResult.btn.x = col * (btnW + 4);
				cellResult.btn.y = row * (BTN_H + 2);
				cellContainer.addChild(cellResult.btn);
				cellButtons.push({btn: cellResult.btn, label: cellResult.label, name: cellName});

				yPos = (row + 1) * (BTN_H + 2);
			}

			maxScroll = Math.max(0, yPos - CELL_AREA_H);
		}

		// ==========================================
		// Cell button factory (instant jump, Spawn pad)
		// ==========================================

		private function makeCellButton(cellName:String, w:Number):Object {
			var btn:Sprite = new Sprite();
			drawBtnBg(btn, w, COL_BTN);

			var tf:TextField = makeLabel(cellName, COL_TEXT, 9, false);
			tf.width = w;
			tf.height = BTN_H;
			tf.y = 5;
			btn.addChild(tf);

			btn.buttonMode = true;
			btn.useHandCursor = true;
			btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				// Instant jump to cell with Spawn pad
				WorldAPI.jumpCorrectRoom(cellName, "Spawn", true);
				e.stopImmediatePropagation();
			});

			return {btn: btn, label: tf};
		}

		// ==========================================
		// Scroll handling
		// ==========================================

		private function onCellWheel(e:MouseEvent):void {
			scrollOffset -= e.delta * 10;
			clampScroll();
			cellContainer.y = -scrollOffset;
		}

		private function onCellTouchDown(e:MouseEvent):void {
			touchScrolling = true;
			touchStartY = e.stageY;
			scrollStartOffset = scrollOffset;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onCellTouchMove);
			stage.addEventListener(MouseEvent.MOUSE_UP, onCellTouchUp);
		}

		private function onCellTouchMove(e:MouseEvent):void {
			if (!touchScrolling) return;
			var delta:Number = touchStartY - e.stageY;
			scrollOffset = scrollStartOffset + delta;
			clampScroll();
			cellContainer.y = -scrollOffset;
		}

		private function onCellTouchUp(e:MouseEvent):void {
			touchScrolling = false;
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onCellTouchMove);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onCellTouchUp);
		}

		private function clampScroll():void {
			if (scrollOffset < 0) scrollOffset = 0;
			if (scrollOffset > maxScroll) scrollOffset = maxScroll;
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

		private function drawBtnBg(btn:Sprite, w:Number, color:uint):void {
			var g:Graphics = btn.graphics;
			g.clear();
			g.beginFill(color, 0.85);
			g.drawRoundRect(0, 0, w, BTN_H, 4);
			g.endFill();
			g.lineStyle(1, COL_RIM, 0.4);
			g.drawRoundRect(0, 0, w, BTN_H, 4);
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
			var fmt:TextFormat = new TextFormat(
				"_sans", size, color, bold, null, null,
				null, null, TextFormatAlign.CENTER
			);
			tf.defaultTextFormat = fmt;
			tf.text = text;
			return tf;
		}

		// ==========================================
		// Drag handling
		// ==========================================

		private function onStartDrag(e:MouseEvent):void {
			dragging = true;
			dragOffX = e.stageX - this.x;
			dragOffY = e.stageY - this.y;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onDragMove);
			stage.addEventListener(MouseEvent.MOUSE_UP, onStopDrag);
			e.stopImmediatePropagation();
		}

		private function onDragMove(e:MouseEvent):void {
			if (!dragging) return;
			this.x = e.stageX - dragOffX;
			this.y = e.stageY - dragOffY;
		}

		private function onStopDrag(e:MouseEvent):void {
			dragging = false;
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDragMove);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onStopDrag);
		}
	}
}
