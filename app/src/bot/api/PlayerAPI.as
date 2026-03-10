package bot.api {

	import flash.events.MouseEvent;
	import flash.utils.getQualifiedClassName;

	import bot.GameAccessor;

	/**
	 * Player API - provides player-related operations: movement, targeting, loadouts, drop management.
	 * Provides player-related operations: movement, targeting, loadouts, drop management.
	 */
	public class PlayerAPI {

		private static const DROP_PARSE_REGEX:RegExp = /(.*)\s+x\s*(\d*)/g;

		/** Walk avatar to a specific position */
		public static function walkTo(xPos:int, yPos:int, walkSpeed:int = 0):void {
			var game:* = GameAccessor.game;
			if (walkSpeed == 0 || walkSpeed == 8) {
				walkSpeed = game.world.WALKSPEED;
			}
			game.world.myAvatar.pMC.walkTo(xPos, yPos, walkSpeed);
			game.world.moveRequest({
				"mc": game.world.myAvatar.pMC,
				"tx": xPos,
				"ty": yPos,
				"sp": walkSpeed
			});
		}

		/** Cancel target if targeting self */
		public static function untargetSelf():void {
			var game:* = GameAccessor.game;
			var target:* = game.world.myAvatar.target;
			if (target && target == game.world.myAvatar) {
				game.world.cancelTarget();
			}
		}

		/** Attack/target a player by name. Returns true if found. */
		public static function attackPlayer(name:String):Boolean {
			var game:* = GameAccessor.game;
			var player:* = game.world.getAvatarByUserName(name.toLowerCase());
			if (player != null && player.pMC != null) {
				game.world.setTarget(player);
				game.world.approachTarget();
				return true;
			}
			return false;
		}

		/** Get avatar data by ID */
		public static function getAvatar(id:int):Object {
			var game:* = GameAccessor.game;
			if (game.world.avatars[id] != null) {
				return game.world.avatars[id].objData;
			}
			return null;
		}

		/** Check if the player is logged in and connected */
		public static function isLoggedIn():Boolean {
			var game:* = GameAccessor.game;
			return (game != null && game.sfc != null && game.sfc.isConnected);
		}

		/** Check if the player has been kicked */
		public static function isKicked():Boolean {
			var game:* = GameAccessor.game;
			return (game.mcLogin != null && game.mcLogin.warning != null && game.mcLogin.warning.visible);
		}

		/** Get player loadouts */
		public static function getLoadouts():Object {
			var game:* = GameAccessor.game;
			return game.world.objInfo["customs"].loadouts;
		}

		/** Get player gender */
		public static function getGender():String {
			var game:* = GameAccessor.game;
			return game.world.myAvatar.objData.strGender.toUpperCase();
		}

		/** Get my avatar's object data */
		public static function getMyData():Object {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.myAvatar == null) return null;
			return game.world.myAvatar.objData;
		}

		/** Get current HP */
		public static function getHP():int {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.myAvatar == null || game.world.myAvatar.dataLeaf == null) return 0;
			return game.world.myAvatar.dataLeaf.intHP;
		}

		/** Get max HP */
		public static function getMaxHP():int {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.myAvatar == null || game.world.myAvatar.dataLeaf == null) return 0;
			return game.world.myAvatar.dataLeaf.intHPMax;
		}

		/** Get current MP */
		public static function getMP():int {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.myAvatar == null || game.world.myAvatar.dataLeaf == null) return 0;
			return game.world.myAvatar.dataLeaf.intMP;
		}

		/** Get current cell name */
		public static function getCurrentCell():String {
			var game:* = GameAccessor.game;
			if (game.world == null) return "";
			return game.world.strFrame;
		}

		/** Get current pad name */
		public static function getCurrentPad():String {
			var game:* = GameAccessor.game;
			if (game.world == null) return "";
			return game.world.strPad;
		}

		/**
		 * Reject all drops except those in the whitelist (comma-separated names).
		 * Supports both custom drops UI and default drops UI.
		 */
		public static function rejectExcept(whitelist:String):void {
			var game:* = GameAccessor.game;
			var pickup:Array = whitelist.split(",");
			for (var p:int = 0; p < pickup.length; p++) {
				pickup[p] = String(pickup[p]).toLowerCase();
			}

			if (game.litePreference.data.bCustomDrops) {
				var source:* = game.cDropsUI.mcDraggable ? game.cDropsUI.mcDraggable.menu : game.cDropsUI;
				for (var i:int = 0; i < source.numChildren; i++) {
					var child:* = source.getChildAt(i);
					if (child.itemObj) {
						var itemName:String = child.itemObj.sName.toLowerCase();
						if (pickup.indexOf(itemName) == -1) {
							child.btNo.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
						}
					}
				}
			} else {
				var children:int = game.ui.dropStack.numChildren;
				for (i = 0; i < children; i++) {
					child = game.ui.dropStack.getChildAt(i);
					var type:String = getQualifiedClassName(child);
					if (type.indexOf("DFrame2MC") != -1) {
						var drop:Object = parseDrop(child.cnt.strName.text);
						var name:String = drop.name;
						if (pickup.indexOf(name) == -1) {
							child.cnt.nbtn.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
						}
					}
				}
			}
		}

		private static function parseDrop(name:*):Object {
			var ret:Object = {};
			var lowercaseName:String = String(name).toLowerCase();
			// trim
			lowercaseName = lowercaseName.replace(/^\s+|\s+$/g, "");
			ret.name = lowercaseName;
			ret.count = 1;
			var result:Object = DROP_PARSE_REGEX.exec(lowercaseName);
			if (result == null) {
				return ret;
			} else {
				ret.name = result[1];
				ret.count = int(result[2]);
				return ret;
			}
		}
	}
}
