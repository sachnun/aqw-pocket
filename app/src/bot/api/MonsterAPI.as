package bot.api {

	import bot.GameAccessor;

	/**
	 * Monster API - provides monster targeting, listing, and attack operations.
	 * Provides monster targeting, listing, and attack operations.
	 * Monsters are sorted by HP (prefer alive, then lowest HP) for efficient farming.
	 */
	public class MonsterAPI {

		/** Attack the best monster target matching the given name. '*' for any. Returns true if target found. */
		public static function attackMonsterByName(name:String):Boolean {
			var bestTarget:* = getBestMonsterTarget(name);
			return attackTarget(bestTarget);
		}

		/** Attack the best monster target matching the given ID. Returns true if target found. */
		public static function attackMonsterByID(id:int):Boolean {
			var bestTarget:* = getBestMonsterTargetByID(id);
			return attackTarget(bestTarget);
		}

		/**
		 * Find the best monster target by name in the current cell.
		 * Sorts by: alive first, then lowest HP, then lowest MonMapID.
		 * Use '*' for wildcard (any monster).
		 */
		public static function getBestMonsterTarget(name:String):* {
			var targetCandidates:Array = [];
			var world:* = GameAccessor.game.world;
			var lowerName:String = name.toLowerCase();
			var isWildcard:Boolean = (name == "*");

			for each (var monster:* in world.getMonstersByCell(world.strFrame)) {
				if (monster.pMC != null) {
					var monName:String = monster.objData.strMonName.toLowerCase();
					if (isWildcard || monName.indexOf(lowerName) > -1) {
						targetCandidates.push(monster);
					}
				}
			}

			if (targetCandidates.length == 0) return null;

			targetCandidates.sort(sortMonstersByHP);
			return targetCandidates[0];
		}

		/** Find the best monster target by MonMapID or MonID in the current cell */
		public static function getBestMonsterTargetByID(id:int):* {
			var targetCandidates:Array = [];
			var world:* = GameAccessor.game.world;

			for each (var monster:* in world.getMonstersByCell(world.strFrame)) {
				if (monster.pMC != null && monster.objData &&
					(monster.objData.MonMapID == id || monster.objData.MonID == id)) {
					targetCandidates.push(monster);
				}
			}

			if (targetCandidates.length == 0) return null;

			targetCandidates.sort(sortMonstersByHP);
			return targetCandidates[0];
		}

		/** Get all available monsters in the current cell as data objects */
		public static function availableMonstersInCell():Array {
			var retMonsters:Array = [];
			var world:* = GameAccessor.game.world;

			for each (var monster:* in world.getMonstersByCell(world.strFrame)) {
				if (monster.pMC != null) {
					retMonsters.push(getMonData(monster));
				}
			}
			return retMonsters;
		}

		/** Get current target monster data, or null if no valid target */
		public static function getTargetMonster():Object {
			var world:* = GameAccessor.game.world;
			var monster:* = world.myAvatar.target;
			if (!monster || (monster.dataLeaf && monster.dataLeaf.intHP <= 0)) {
				world.cancelTarget();
				return null;
			}
			return getMonData(monster);
		}

		/** Get all monsters in the current map */
		public static function getMonsters():Array {
			var retMonsters:Array = [];
			for each (var monster:* in GameAccessor.game.world.monsters) {
				retMonsters.push(getMonData(monster));
			}
			return retMonsters;
		}

		/** Check if current target is alive */
		public static function isTargetAlive():Boolean {
			var world:* = GameAccessor.game.world;
			if (world == null || world.myAvatar == null) return false;
			var target:* = world.myAvatar.target;
			if (target == null || target.dataLeaf == null) return false;
			return target.dataLeaf.intHP > 0;
		}

		/** Check if there's a valid target */
		public static function hasTarget():Boolean {
			var world:* = GameAccessor.game.world;
			if (world == null || world.myAvatar == null) return false;
			return world.myAvatar.target != null;
		}

		/** Extract monster data into a plain object */
		public static function getMonData(mon:Object):Object {
			var monsterData:Object = {};
			for (var prop:String in mon.objData) {
				monsterData[prop] = mon.objData[prop];
			}
			if (mon.dataLeaf) {
				monsterData.intHP = mon.dataLeaf.intHP;
				monsterData.intHPMax = mon.dataLeaf.intHPMax;
				monsterData.intState = mon.dataLeaf.intState;
			}
			return monsterData;
		}

		/** Sort function: alive first, then lowest HP, then lowest MonMapID */
		private static function sortMonstersByHP(a:*, b:*):Number {
			var aHP:int = (a.dataLeaf && a.dataLeaf.intHP) ? a.dataLeaf.intHP : 0;
			var bHP:int = (b.dataLeaf && b.dataLeaf.intHP) ? b.dataLeaf.intHP : 0;

			var aAlive:Boolean = aHP > 0;
			var bAlive:Boolean = bHP > 0;

			if (aAlive != bAlive) {
				return aAlive ? -1 : 1;
			}

			if (aHP != bHP) {
				return aHP - bHP;
			}

			var aMapID:int = a.objData ? a.objData.MonMapID : 0;
			var bMapID:int = b.objData ? b.objData.MonMapID : 0;
			return aMapID - bMapID;
		}

		/** Set target and approach. Returns true on success. */
		private static function attackTarget(target:*):Boolean {
			if (target != null && target.pMC != null) {
				GameAccessor.game.world.setTarget(target);
				GameAccessor.game.world.approachTarget();
				return true;
			}
			return false;
		}
	}
}
