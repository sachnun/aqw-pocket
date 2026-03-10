package bot.api {

	import bot.GameAccessor;

	/**
	 * Combat API - provides combat utilities: infinite range and magnetize.
	 * Provides combat utilities: infinite range and magnetize.
	 */
	public class CombatAPI {

		/**
		 * Teleport the current target to the player's position.
		 * Useful for ensuring attacks hit without needing to approach.
		 */
		public static function magnetize():void {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.myAvatar == null) return;

			var target:* = game.world.myAvatar.target;
			if (target && target.pMC) {
				target.pMC.x = game.world.myAvatar.pMC.x;
				target.pMC.y = game.world.myAvatar.pMC.y;
			}
		}

		/**
		 * Set all skill ranges to 20000, effectively making all skills hit
		 * regardless of distance to the target.
		 */
		public static function infiniteRange():void {
			var game:* = GameAccessor.game;
			if (game.world == null || game.world.actions == null) return;

			var active:Array = game.world.actions.active;
			for (var i:int = 0; i < 6; i++) {
				if (active[i] != null) {
					active[i].range = 20000;
				}
			}
		}

		/** Approach the current target */
		public static function approachTarget():void {
			var game:* = GameAccessor.game;
			if (game.world == null) return;
			game.world.approachTarget();
		}

		/** Cancel the current target */
		public static function cancelTarget():void {
			var game:* = GameAccessor.game;
			if (game.world == null) return;
			game.world.cancelTarget();
		}

		/** Set a specific entity as target */
		public static function setTarget(entity:*):void {
			var game:* = GameAccessor.game;
			if (game.world == null || entity == null) return;
			game.world.setTarget(entity);
		}
	}
}
