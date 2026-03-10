package bot.api {

	import flash.events.TimerEvent;
	import flash.utils.Timer;

	import bot.GameAccessor;

	/**
	 * Auras API - provides aura tracking for players and monsters.
	 * Provides aura tracking for players and monsters with automatic cleanup of expired auras.
	 */
	public class AurasAPI {

		private static var _cleanupTimer:Timer = null;
		private static var _initTimer:Timer = null;
		private static var _initialized:Boolean = false;

		/** Initialize the Auras system. Waits for world to be ready, then starts auto-cleanup. */
		public static function initialize():void {
			if (_initialized) return;

			_initTimer = new Timer(500);
			_initTimer.addEventListener(TimerEvent.TIMER, checkGameReady);
			_initTimer.start();
		}

		private static function checkGameReady(event:TimerEvent):void {
			try {
				var world:* = GameAccessor.game.world;
				if (world && world.uoTree && world.monTree) {
					_initTimer.stop();
					_initTimer.removeEventListener(TimerEvent.TIMER, checkGameReady);
					_initTimer = null;
					_initialized = true;
					startAuraAutoCleanup(5);
				}
			} catch (e:Error) {
			}
		}

		/** Get auras for a subject: 'Self' for player, anything else for current target monster */
		public static function getSubjectAuras(subject:String):Array {
			var game:* = GameAccessor.game;
			if (subject == "Self") {
				var userObj:* = game.world.uoTree[game.sfc.myUserName.toLowerCase()];
				if (!userObj) return [];
				return rebuildAuraArray(userObj.auras);
			} else {
				var monID:int = 0;
				if (game.world.myAvatar.target != null) {
					monID = game.world.myAvatar.target.dataLeaf.MonMapID;
				}
				var monObj:* = game.world.monTree[monID];
				if (!monObj) return [];
				return rebuildAuraArray(monObj.auras);
			}
		}

		/** Rebuild aura array, filtering out expired/null auras and normalizing values */
		public static function rebuildAuraArray(auras:Object):Array {
			var rebuiltAuras:Array = [];
			if (!auras) return rebuiltAuras;

			for (var i:int = 0; i < auras.length; i++) {
				var aura:Object = auras[i];
				if (!aura) continue;
				if (!aura.hasOwnProperty("nam") || !aura.nam) continue;
				if (aura.e == 1) continue;

				var rebuiltAura:Object = {};
				var hasVal:Boolean = false;

				for (var key:String in aura) {
					if (key == "cLeaf") {
						rebuiltAura[key] = "cycle_";
					} else if (key == "val") {
						var rawVal:* = aura[key];
						if (rawVal == null || isNaN(rawVal)) {
							rebuiltAura[key] = 1;
						} else {
							rebuiltAura[key] = rawVal;
						}
						hasVal = true;
					} else {
						rebuiltAura[key] = aura[key];
					}
				}
				if (!hasVal) {
					rebuiltAura.val = 1;
				}
				rebuiltAuras.push(rebuiltAura);
			}
			return rebuiltAuras;
		}

		/** Get player auras by player name */
		public static function getPlayerAura(playerName:String):Array {
			try {
				var plrUser:String = playerName.toLowerCase();
				var userObj:* = GameAccessor.game.world.uoTree[plrUser];
				if (!userObj) return [];
				return rebuildAuraArray(userObj.auras);
			} catch (e:Error) {
			}
			return [];
		}

		/** Get monster auras by monster name */
		public static function getMonsterAuraByName(monsterName:String):Array {
			try {
				var monID:int = 0;
				var lowerMonsterName:String = monsterName.toLowerCase();
				for each (var monster:* in GameAccessor.game.world.monsters) {
					if (monster && monster.objData.strMonName.toLowerCase() == lowerMonsterName) {
						monID = monster.objData.MonMapID;
					}
				}
				var monObj:* = GameAccessor.game.world.monTree[monID];
				if (!monObj) return [];
				return rebuildAuraArray(monObj.auras);
			} catch (e:Error) {
			}
			return [];
		}

		/** Get monster auras by MonMapID */
		public static function getMonsterAuraByID(monID:int):Array {
			try {
				var monObj:* = GameAccessor.game.world.monTree[monID];
				if (!monObj) return [];
				return rebuildAuraArray(monObj.auras);
			} catch (e:Error) {
			}
			return [];
		}

		/** Check if any of the given aura names (comma-separated) are active on the subject */
		public static function hasAnyActiveAura(subject:String, auraNames:String):Boolean {
			var auraList:Array = auraNames.split(",");
			var auras:Array;
			try {
				auras = getSubjectAuras(subject);
			} catch (e:Error) {
				return false;
			}

			for (var i:int = 0; i < auras.length; i++) {
				var auraNameLower:String = auras[i].nam.toLowerCase();
				for (var j:int = 0; j < auraList.length; j++) {
					var checkName:String = auraList[j];
					// trim
					checkName = checkName.replace(/^\s+|\s+$/g, "");
					if (auraNameLower == checkName.toLowerCase()) {
						return true;
					}
				}
			}
			return false;
		}

		/** Get the value of a specific aura on the subject. Returns -1 if not found. */
		public static function getAuraValue(subject:String, auraName:String):Number {
			var auras:Array;
			try {
				auras = getSubjectAuras(subject);
			} catch (e:Error) {
				return -1;
			}

			var lowerAuraName:String = auraName.toLowerCase();
			for (var i:int = 0; i < auras.length; i++) {
				if (auras[i].nam.toLowerCase() == lowerAuraName) {
					return auras[i].val;
				}
			}
			return -1;
		}

		/** Rebuild full uoTree data for a player, with cleaned auras */
		public static function rebuilduoTree(playerName:String):Object {
			var plrUser:String = playerName.toLowerCase();
			var userObj:* = GameAccessor.game.world.uoTree[plrUser];
			if (!userObj) return {};

			var rebuiltObj:Object = {};
			for (var prop:String in userObj) {
				if (prop == "auras") {
					rebuiltObj[prop] = rebuildAuraArray(userObj.auras);
				} else {
					rebuiltObj[prop] = userObj[prop];
				}
			}
			return rebuiltObj;
		}

		/** Rebuild full monTree data for a monster, with cleaned auras */
		public static function rebuildmonTree(monID:int):Object {
			var monObj:* = GameAccessor.game.world.monTree[monID];
			if (!monObj) return {};

			var rebuiltObj:Object = {};
			for (var prop:String in monObj) {
				if (prop == "auras") {
					rebuiltObj[prop] = rebuildAuraArray(monObj.auras);
				} else {
					rebuiltObj[prop] = monObj[prop];
				}
			}
			return rebuiltObj;
		}

		/** Start auto-cleanup timer for expired auras */
		public static function startAuraAutoCleanup(intervalSeconds:int = 5):void {
			if (_cleanupTimer != null) return;

			_cleanupTimer = new Timer(intervalSeconds * 1000);
			_cleanupTimer.addEventListener(TimerEvent.TIMER, onCleanupTimer);
			_cleanupTimer.start();
		}

		/** Stop auto-cleanup timer */
		public static function stopAuraAutoCleanup():void {
			if (_cleanupTimer == null) return;

			_cleanupTimer.stop();
			_cleanupTimer.removeEventListener(TimerEvent.TIMER, onCleanupTimer);
			_cleanupTimer = null;
		}

		private static function onCleanupTimer(event:TimerEvent):void {
			var world:* = GameAccessor.game.world;
			if (!world) return;

			// Clean player auras
			for (var playerName:String in world.uoTree) {
				var userObj:* = world.uoTree[playerName];
				if (userObj && userObj.auras is Array) {
					cleanExpiredAuras(userObj.auras);
				}
			}

			// Clean monster auras
			for (var monID:String in world.monTree) {
				var monObj:* = world.monTree[monID];
				if (monObj && monObj.auras is Array) {
					cleanExpiredAuras(monObj.auras);
				}
			}
		}

		private static function cleanExpiredAuras(auras:Array):int {
			var removedCount:int = 0;
			for (var i:int = auras.length - 1; i >= 0; i--) {
				var aura:Object = auras[i];
				if (!aura || !aura.hasOwnProperty("nam") || !aura.nam || aura.e == 1) {
					auras.splice(i, 1);
					removedCount++;
				}
			}
			return removedCount;
		}

		/** Cleanup resources when shutting down */
		public static function dispose():void {
			stopAuraAutoCleanup();
			if (_initTimer != null) {
				_initTimer.stop();
				_initTimer.removeEventListener(TimerEvent.TIMER, checkGameReady);
				_initTimer = null;
			}
			_initialized = false;
		}
	}
}
