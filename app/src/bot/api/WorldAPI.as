package bot.api {

	import flash.display.DisplayObject;
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	import bot.GameAccessor;

	/**
	 * World API - provides world/map navigation, UI utilities, and performance toggles.
	 * Provides world/map navigation, UI utilities, and performance toggles.
	 */
	public class WorldAPI {

		private static const PAD_NAMES_REGEX:RegExp = /(Spawn|Center|Left|Right|Up|Down|Top|Bottom)/;

		/**
		 * Jump to a cell with smart pad correction.
		 * If autoCorrect is true, it avoids pads occupied by other players.
		 */
		public static function jumpCorrectRoom(cell:String, pad:String, autoCorrect:Boolean = true, clientOnly:Boolean = false):void {
			var world:* = GameAccessor.game.world;

			if (!autoCorrect) {
				world.moveToCell(cell, pad, clientOnly);
			} else {
				var users:Array = world.areaUsers;
				users.splice(users.indexOf(GameAccessor.game.sfc.myUserName), 1);
				users.sort();

				if (users.length <= 1) {
					world.moveToCell(cell, pad, clientOnly);
				} else {
					var uoTree:* = world.uoTree;
					var usersCell:String = world.strFrame;
					var usersPad:String = "Left";
					for (var i:int = 0; i < users.length; i++) {
						var userObj:* = uoTree[users[i]];
						usersCell = userObj.strFrame;
						usersPad = userObj.strPad;
						if (cell == usersCell && pad != usersPad) {
							break;
						}
					}
					world.moveToCell(cell, usersPad, clientOnly);
				}

				var jumpTimer:Timer = new Timer(50, 1);
				jumpTimer.addEventListener(TimerEvent.TIMER, function (e:TimerEvent):void {
					jumpCorrectPad(cell, clientOnly);
					jumpTimer.stop();
					jumpTimer.removeEventListener(TimerEvent.TIMER, arguments.callee);
				});
				jumpTimer.start();
			}
		}

		/** Correct pad position within a cell, preferring "Left" */
		public static function jumpCorrectPad(cell:String, clientOnly:Boolean = false):void {
			var cellPad:String = "Left";
			var padArr:Array = getCellPads();
			var world:* = GameAccessor.game.world;

			if (padArr.indexOf(cellPad) >= 0) {
				if (world.strPad === cellPad) return;
				world.moveToCell(cell, cellPad, clientOnly);
			} else if (padArr.length > 0) {
				cellPad = padArr[0];
				if (world.strPad === cellPad) return;
				world.moveToCell(cell, cellPad, clientOnly);
			}
		}

		/** Get available pads in the current cell */
		public static function getCellPads():Array {
			var cellPads:Array = [];
			var map:* = GameAccessor.game.world.map;
			if (map == null) return cellPads;

			var cellPadsCnt:int = map.numChildren;
			for (var i:int = 0; i < cellPadsCnt; ++i) {
				var child:DisplayObject = map.getChildAt(i);
				if (PAD_NAMES_REGEX.test(child.name)) {
					cellPads.push(child.name);
				}
			}
			return cellPads;
		}

		/** Simple cell jump without auto-correction */
		public static function moveToCell(cell:String, pad:String = "Left"):void {
			var world:* = GameAccessor.game.world;
			if (world == null) return;
			world.moveToCell(cell, pad);
		}

		/** Join a map room. e.g. joinMap("battleon") */
		public static function joinMap(mapName:String, cell:String = "Enter", pad:String = "Spawn"):void {
			var game:* = GameAccessor.game;
			if (game.world == null) return;
			game.world.sendMoveRequest(mapName, cell, pad);
		}

		/** Disable death ad popup */
		public static function disableDeathAd(enable:Boolean):void {
			GameAccessor.game.userPreference.data.bDeathAd = !enable;
		}

		/** Skip cutscenes by clearing the external SWF container and showing interface */
		public static function skipCutscenes():void {
			var game:* = GameAccessor.game;
			while (game.mcExtSWF.numChildren > 0) {
				game.mcExtSWF.removeChildAt(0);
			}
			game.showInterface();
		}

		/**
		 * Toggle visibility of other players.
		 * When enabled, other players' characters, names, shadows, and pets are hidden.
		 */
		public static function hidePlayers(enabled:Boolean):void {
			var world:* = GameAccessor.game.world;
			var currentFrame:String = world.strFrame;

			for each (var avatar:* in world.avatars) {
				if (avatar != null && avatar.pnm != null && !avatar.isMyAvatar) {
					if (enabled) {
						avatar.hideMC();
					} else if (avatar.strFrame == currentFrame) {
						avatar.showMC();
					}
				}
			}
		}

		/** Toggle world visibility for extreme lag reduction */
		public static function killLag(enable:Boolean):void {
			GameAccessor.game.world.visible = !enable;
		}

		/** Get the current map/room name */
		public static function getMapName():String {
			var game:* = GameAccessor.game;
			if (game.world == null) return "";
			return game.world.strMapName || "";
		}

		/** Get list of players in the current room */
		public static function getPlayersInRoom():Array {
			var game:* = GameAccessor.game;
			if (game.world == null) return [];
			return game.world.areaUsers || [];
		}

		/** Get the current room number */
		public static function getRoomNumber():int {
			var game:* = GameAccessor.game;
			if (game.world == null) return -1;
			return game.world.curRoom || -1;
		}

		/**
		 * Get all cell names available in the current map.
		 * Reads frame labels from the map MovieClip's current scene.
		 */
		public static function getCells():Array {
			var cells:Array = [];
			var world:* = GameAccessor.game.world;
			if (world == null || world.map == null) return cells;

			try {
				var labels:Array = world.map.currentScene.labels;
				for (var i:int = 0; i < labels.length; i++) {
					cells.push(labels[i].name);
				}
			} catch (err:Error) {}

			return cells;
		}
	}
}
