package bot.ui {

	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getTimer;

	import bot.GameAccessor;
	import bot.api.MonsterAPI;
	import bot.api.PlayerAPI;
	import bot.api.WorldAPI;
	import bot.packet.PacketHandler;

	/**
	 * MapIntelPanel - read-only intel panel for current map/cell.
	 * Shows current monsters and session drop history.
	 */
	public class MapIntelPanel extends Sprite {

		private static const PANEL_W:Number = 320;
		private static const HEADER_H:Number = 28;
		private static const MARGIN:Number = 8;
		private static const ROW_H:Number = 20;
		private static const COL_BG:uint = 0x111111;
		private static const COL_HEADER:uint = 0x1a1a1a;
		private static const COL_RIM:uint = 0x555555;
		private static const COL_TEXT:uint = 0xcccccc;
		private static const COL_ACCENT:uint = 0x44cc44;
		private static const COL_SUB:uint = 0x888888;
		private static const LIST_AREA_H:Number = 220;

		private static const REFRESH_MS:int = 400;
		private static const MAX_DROPS:int = 200;

		private var bg:Shape;
		private var headerBar:Sprite;
		private var content:Sprite;

		private var statusField:TextField;
		private var counterField:TextField;

		private var listScrollArea:Sprite;
		private var listContainer:Sprite;
		private var listMask:Shape;

		private var dragging:Boolean = false;
		private var dragOffX:Number;
		private var dragOffY:Number;

		private var scrollOffset:Number = 0;
		private var maxScroll:Number = 0;
		private var touchScrolling:Boolean = false;
		private var touchStartY:Number = 0;
		private var scrollStartOffset:Number = 0;

		private var lastRefreshAt:int = 0;
		private var hasCaptureOwner:Boolean = false;

		private var dropHistory:Array = [];
		private var dropIndex:Object = {};
		private var seenPacket:Object = {};

		public function MapIntelPanel() {
			buildPanel();
			this.x = 370;
			this.y = 60;
		}

		public function refresh():void {
			ensurePacketCapture();
			updateSnapshot();
		}

		private function buildPanel():void {
			bg = new Shape();
			addChild(bg);

			headerBar = new Sprite();
			headerBar.graphics.beginFill(COL_HEADER, 0.95);
			headerBar.graphics.drawRoundRect(0, 0, PANEL_W, HEADER_H, 6, 6);
			headerBar.graphics.endFill();

			var title:TextField = makeLabel("Map Intel", COL_ACCENT, 11, true, TextFormatAlign.LEFT);
			title.x = MARGIN;
			title.y = 5;
			title.width = PANEL_W - 60;
			headerBar.addChild(title);

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

			content = new Sprite();
			content.y = HEADER_H + 4;
			addChild(content);

			var yOff:Number = 0;

			statusField = makeLabel("-", COL_TEXT, 9, false, TextFormatAlign.LEFT);
			statusField.width = PANEL_W - MARGIN * 2;
			statusField.height = 18;
			statusField.x = MARGIN;
			statusField.y = yOff;
			content.addChild(statusField);
			yOff += 17;

			counterField = makeLabel("Monsters: 0 | Drops: 0", COL_SUB, 9, false, TextFormatAlign.LEFT);
			counterField.width = PANEL_W - MARGIN * 2;
			counterField.height = 18;
			counterField.x = MARGIN;
			counterField.y = yOff;
			content.addChild(counterField);
			yOff += 18;

			listScrollArea = new Sprite();
			listScrollArea.x = MARGIN;
			listScrollArea.y = yOff;
			content.addChild(listScrollArea);

			listContainer = new Sprite();
			listScrollArea.addChild(listContainer);

			listMask = new Shape();
			listMask.graphics.beginFill(0x000000);
			listMask.graphics.drawRect(0, 0, PANEL_W - MARGIN * 2, LIST_AREA_H);
			listMask.graphics.endFill();
			listScrollArea.addChild(listMask);
			listContainer.mask = listMask;

			listScrollArea.addEventListener(MouseEvent.MOUSE_WHEEL, onListWheel);
			listScrollArea.addEventListener(MouseEvent.MOUSE_DOWN, onListTouchDown);

			yOff += LIST_AREA_H + 8;
			drawBackgroundWithHeight(HEADER_H + yOff + 8);

			addEventListener(Event.ENTER_FRAME, onFrame);
		}

		private function onFrame(e:Event):void {
			if (!visible) return;

			var now:int = getTimer();
			if (now - lastRefreshAt < REFRESH_MS) return;

			updateSnapshot();
		}

		private function ensurePacketCapture():void {
			if (hasCaptureOwner) return;
			if (!PacketHandler.isCapturing()) {
				PacketHandler.startCapture(onPacketCandidate);
				hasCaptureOwner = true;
			}
		}

		private function onPacketCandidate(packet:String):void {
			if (packet == null || packet.length == 0) return;
			if (!looksLikeDropPacket(packet)) return;

			var candidateName:String = extractNameFromPacket(packet);
			if (candidateName.length == 0) {
				candidateName = "(packet:" + extractCmd(packet) + ")";
			}

			upsertDrop(candidateName, 1, "Candidate", "packet");
		}

		private function updateSnapshot():void {
			lastRefreshAt = getTimer();
			ensurePacketCapture();
			ingestPacketLog();
			scanDropUI();

			var monsters:Array = getCurrentMonsters();
			render(monsters, dropHistory);
		}

		private function getCurrentMonsters():Array {
			var source:Array = MonsterAPI.getMonsters();
			var result:Array = [];
			for (var i:int = 0; i < source.length; i++) {
				var mon:Object = source[i];
				if (mon == null || mon.strMonName == null) continue;
				result.push(mon);
			}

			result.sort(function(a:Object, b:Object):Number {
				var ahp:int = a.intHP != undefined ? int(a.intHP) : 0;
				var bhp:int = b.intHP != undefined ? int(b.intHP) : 0;
				var aAlive:Boolean = ahp > 0;
				var bAlive:Boolean = bhp > 0;
				if (aAlive != bAlive) return aAlive ? -1 : 1;
				if (ahp != bhp) return ahp - bhp;
				var aid:int = a.MonMapID != undefined ? int(a.MonMapID) : 0;
				var bid:int = b.MonMapID != undefined ? int(b.MonMapID) : 0;
				return aid - bid;
			});

			return result;
		}

		private function ingestPacketLog():void {
			var packets:Array = PacketHandler.getPacketLog();
			for (var i:int = 0; i < packets.length; i++) {
				var raw:String = packets[i];
				if (raw == null || raw.length == 0) continue;
				if (seenPacket[raw] === true) continue;
				seenPacket[raw] = true;

				if (!looksLikeDropPacket(raw)) continue;
				var packetName:String = extractNameFromPacket(raw);
				if (packetName.length == 0) {
					packetName = "(packet:" + extractCmd(raw) + ")";
				}
				upsertDrop(packetName, 1, "Candidate", "packet");
			}
		}

		private function looksLikeDropPacket(packet:String):Boolean {
			var cmd:String = extractCmd(packet).toLowerCase();
			if (cmd.length == 0) return false;
			if (cmd.indexOf("drop") > -1) return true;
			if (cmd.indexOf("item") > -1) return true;
			if (cmd.indexOf("loot") > -1) return true;
			if (cmd.indexOf("get") > -1) return true;
			return false;
		}

		private function extractCmd(packet:String):String {
			var parts:Array = packet.split("%");
			var clean:Array = [];
			for (var i:int = 0; i < parts.length; i++) {
				if (parts[i] != null && String(parts[i]).length > 0) clean.push(parts[i]);
			}
			if (clean.length >= 3) return String(clean[2]);
			return "";
		}

		private function extractNameFromPacket(packet:String):String {
			var parts:Array = packet.split("%");
			for (var i:int = 0; i < parts.length; i++) {
				var token:String = normalizeName(parts[i]);
				if (token.length < 3) continue;
				if (isNumeric(token)) continue;
				if (token == "xt" || token == "zm") continue;
				if (token.indexOf("(") > -1 || token.indexOf(")") > -1) continue;
				if (token.toLowerCase().indexOf("drop") > -1) continue;
				if (token.toLowerCase().indexOf("item") > -1) continue;
				if (token.toLowerCase().indexOf("loot") > -1) continue;
				if (token.toLowerCase().indexOf("get") > -1) continue;
				return token;
			}
			return "";
		}

		private function scanDropUI():void {
			var game:* = GameAccessor.game;
			if (game == null) return;

			try {
				if (game.litePreference && game.litePreference.data && game.litePreference.data.bCustomDrops) {
					var source:* = game.cDropsUI && game.cDropsUI.mcDraggable ? game.cDropsUI.mcDraggable.menu : game.cDropsUI;
					if (source != null) scanCustomDrops(source);
				} else if (game.ui != null && game.ui.dropStack != null) {
					scanDefaultDropStack(game.ui.dropStack);
				}
			} catch (err:Error) {}
		}

		private function scanCustomDrops(source:*):void {
			for (var i:int = 0; i < source.numChildren; i++) {
				var child:* = source.getChildAt(i);
				if (child == null || child.itemObj == null) continue;
				var itemName:String = normalizeName(child.itemObj.sName);
				if (itemName.length == 0) continue;
				upsertDrop(itemName, 1, "Confirmed", "ui");
			}
		}

		private function scanDefaultDropStack(dropStack:*):void {
			for (var i:int = 0; i < dropStack.numChildren; i++) {
				var child:* = dropStack.getChildAt(i);
				if (child == null) continue;
				var type:String = getQualifiedClassName(child);
				if (type.indexOf("DFrame2MC") == -1) continue;

				var rawText:String = "";
				if (child.cnt != null && child.cnt.strName != null) {
					rawText = String(child.cnt.strName.text);
				}
				if (rawText.length == 0) continue;

				var parsed:Object = parseDropText(rawText);
				if (parsed.name.length == 0) continue;
				upsertDrop(parsed.name, parsed.count, "Confirmed", "ui");
			}
		}

		private function parseDropText(nameText:String):Object {
			var ret:Object = {
				name: normalizeName(nameText),
				count: 1
			};

			var regex:RegExp = /(.*)\s+x\s*(\d+)/i;
			var match:Object = regex.exec(nameText);
			if (match != null) {
				ret.name = normalizeName(String(match[1]));
				ret.count = int(match[2]);
				if (ret.count <= 0) ret.count = 1;
			}

			return ret;
		}

		private function upsertDrop(itemName:String, qty:int, status:String, source:String):void {
			var key:String = normalizeName(itemName).toLowerCase();
			if (key.length == 0) return;

			var now:int = getTimer();
			var row:Object = dropIndex[key];
			if (row == null) {
				row = {
					name: itemName,
					qty: 0,
					status: status,
					source: source,
					seen: 0,
					lastSeen: now
				};
				dropIndex[key] = row;
				dropHistory.unshift(row);
			} else {
				if (status == "Confirmed") row.status = "Confirmed";
				row.lastSeen = now;
			}

			row.seen += 1;
			row.qty += Math.max(1, qty);

			var idx:int = dropHistory.indexOf(row);
			if (idx > 0) {
				dropHistory.splice(idx, 1);
				dropHistory.unshift(row);
			}

			while (dropHistory.length > MAX_DROPS) {
				var removed:Object = dropHistory.pop();
				if (removed != null) {
					delete dropIndex[String(removed.name).toLowerCase()];
				}
			}
		}

		private function render(monsters:Array, drops:Array):void {
			while (listContainer.numChildren > 0) {
				listContainer.removeChildAt(0);
			}

			statusField.text = WorldAPI.getMapName() + " | " + PlayerAPI.getCurrentCell() + " | " + PlayerAPI.getCurrentPad();
			counterField.text = "Monsters: " + monsters.length + " | Drops(session): " + drops.length;

			var yOff:Number = 0;
			yOff = drawHeaderRow("MONSTERS IN MAP", yOff);

			if (monsters.length == 0) {
				yOff = drawTextRow("- no monster found", COL_SUB, yOff);
			} else {
				for (var i:int = 0; i < monsters.length; i++) {
					var mon:Object = monsters[i];
					var hp:int = mon.intHP != undefined ? int(mon.intHP) : 0;
					var hpMax:int = mon.intHPMax != undefined ? int(mon.intHPMax) : 0;
					var monCell:String = mon.strFrame != undefined ? String(mon.strFrame) : "";
					var aliveTag:String = hp > 0 ? "[ALIVE]" : "[DEAD]";
					var monText:String = aliveTag + " " + mon.strMonName + "  " + hp + "/" + hpMax;
					if (monCell.length > 0) {
						monText += "  @" + monCell;
					}
					yOff = drawTextRow(monText, hp > 0 ? COL_TEXT : COL_SUB, yOff);
				}
			}

			yOff += 6;
			yOff = drawHeaderRow("ITEMS OBTAINED (SESSION)", yOff);

			if (drops.length == 0) {
				yOff = drawTextRow("- no drops yet", COL_SUB, yOff);
			} else {
				for (i = 0; i < drops.length; i++) {
					var d:Object = drops[i];
					var tag:String = d.status == "Confirmed" ? "[OK]" : "[?]";
					var dropText:String = tag + " " + d.name + " x" + d.qty;
					yOff = drawTextRow(dropText, d.status == "Confirmed" ? COL_ACCENT : COL_TEXT, yOff);
				}
			}

			maxScroll = Math.max(0, yOff - LIST_AREA_H);
			clampScroll();
			listContainer.y = -scrollOffset;
		}

		private function drawHeaderRow(text:String, yOff:Number):Number {
			return drawTextRow(text, COL_SUB, yOff);
		}

		private function drawTextRow(text:String, color:uint, yOff:Number):Number {
			var tf:TextField = makeLabel(text, color, 9, false, TextFormatAlign.LEFT);
			tf.width = PANEL_W - MARGIN * 2;
			tf.height = ROW_H;
			tf.x = 0;
			tf.y = yOff;
			listContainer.addChild(tf);
			return yOff + ROW_H;
		}

		private function onListWheel(e:MouseEvent):void {
			scrollOffset -= e.delta * 10;
			clampScroll();
			listContainer.y = -scrollOffset;
		}

		private function onListTouchDown(e:MouseEvent):void {
			touchScrolling = true;
			touchStartY = e.stageY;
			scrollStartOffset = scrollOffset;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onListTouchMove);
			stage.addEventListener(MouseEvent.MOUSE_UP, onListTouchUp);
		}

		private function onListTouchMove(e:MouseEvent):void {
			if (!touchScrolling) return;
			var delta:Number = touchStartY - e.stageY;
			scrollOffset = scrollStartOffset + delta;
			clampScroll();
			listContainer.y = -scrollOffset;
		}

		private function onListTouchUp(e:MouseEvent):void {
			touchScrolling = false;
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onListTouchMove);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onListTouchUp);
		}

		private function clampScroll():void {
			if (scrollOffset < 0) scrollOffset = 0;
			if (scrollOffset > maxScroll) scrollOffset = maxScroll;
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

		private function makeLabel(text:String, color:uint, size:int, bold:Boolean, align:String = TextFormatAlign.CENTER):TextField {
			var tf:TextField = new TextField();
			tf.selectable = false;
			tf.mouseEnabled = false;
			var fmt:TextFormat = new TextFormat("_sans", size, color, bold, null, null, null, null, align);
			tf.defaultTextFormat = fmt;
			tf.text = text;
			return tf;
		}

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

		private function normalizeName(value:*):String {
			if (value == null) return "";
			var out:String = String(value);
			out = out.replace(/^\s+|\s+$/g, "");
			return out;
		}

		private function isNumeric(s:String):Boolean {
			if (s == null || s.length == 0) return false;
			return /^\d+$/.test(s);
		}
	}
}
