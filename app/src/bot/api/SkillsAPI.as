package bot.api {

	import bot.GameAccessor;

	/**
	 * Skills API - provides proper skill cooldown checking with haste calculation and GCD support.
	 * Provides proper skill cooldown checking with haste calculation and GCD support.
	 * This is more accurate than the simple fireSkill in SkillBar.as.
	 */
	public class SkillsAPI {

		/**
		 * Check if a skill at the given index (0-5) can be used.
		 * Accounts for: target alive, GCD, haste-adjusted cooldown, skill lock.
		 */
		public static function canUseSkill(index:int):Boolean {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.myAvatar == null) return false;

			var skill:* = game.world.actions.active[index];
			if (skill == null) return false;

			return (game.world.myAvatar.target != null
				&& game.world.myAvatar.target.dataLeaf != null
				&& game.world.myAvatar.target.dataLeaf.intHP > 0
				&& actionTimeCheck(skill)
				&& skill.isOK
				&& !skill.skillLock
				&& !skill.lock);
		}

		/**
		 * Use a skill at the given index (0-5).
		 * Returns true if the skill was successfully activated.
		 */
		public static function useSkill(index:int):Boolean {
			var game:* = GameAccessor.game;
			if (game.world == null) return false;

			var skill:* = game.world.actions.active[index];
			if (skill != null && actionTimeCheck(skill)) {
				game.world.testAction(skill);
				return true;
			}
			return false;
		}

		/** Get the number of available active skills */
		public static function getSkillCount():int {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.actions == null) return 0;
			return game.world.actions.active.length;
		}

		/** Get skill data at the given index */
		public static function getSkillData(index:int):Object {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.actions == null) return null;
			var skill:* = game.world.actions.active[index];
			if (skill == null) return null;

			return {
				name: skill.nam,
				desc: skill.desc,
				cd: skill.cd,
				mana: skill.mp,
				range: skill.range,
				isOK: skill.isOK,
				locked: skill.skillLock || skill.lock
			};
		}

		/**
		 * Check if a skill's cooldown has elapsed, accounting for haste.
		 * Core timing check accounting for haste and GCD.
		 */
		private static function actionTimeCheck(skill:*):Boolean {
			var game:* = GameAccessor.game;
			var currentTime:Number = new Date().getTime();

			// Global cooldown check
			if (currentTime - game.world.GCDTS < game.world.GCD) {
				return false;
			}

			// Haste multiplier: clamped between -1 and 0.5, then inverted
			var hasteMultiplier:Number = 1 - Math.min(Math.max(game.world.myAvatar.dataLeaf.sta.$tha, -1), 0.5);

			// Per-skill cooldown check with haste adjustment
			var finalCD:int = 0;
			if (skill.OldCD != null) {
				finalCD = Math.round(skill.OldCD * hasteMultiplier);
			} else {
				finalCD = Math.round(skill.cd * hasteMultiplier);
			}

			if (currentTime - skill.ts >= finalCD) {
				delete skill.OldCD;
				return true;
			}

			return false;
		}
	}
}
