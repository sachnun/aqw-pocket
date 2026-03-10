package bot.module {

	/**
	 * Disable Collisions module - removes wall collision arrays.
	 * Clears wall collision arrays in-place every frame, allowing the player
	 * to walk through walls. Survives cell and map changes.
	 */
	public class DisableCollisions extends Module {

		public function DisableCollisions() {
			super("DisableCollisions");
		}

		override public function onToggle(game:*):void {
			if (game == null || game.world == null) return;

			var world:* = game.world;
			if (enabled) {
				clearCollisions(world);
			} else {
				// Reload current cell to restore proper collision data
				try {
					if (world.strFrame != null && world.strFrame != "") {
						world.moveToCell(world.strFrame, world.strPad || "Left");
					}
				} catch (e:Error) {}
			}
		}

		override public function onFrame(game:*):void {
			if (game == null || game.world == null) return;
			clearCollisions(game.world);
		}

		/**
		 * Clear collision arrays in-place so any cached references held by
		 * the game's walk/collision engine are also emptied.
		 */
		private static function clearCollisions(world:*):void {
			if (world.arrSolid is Array) {
				world.arrSolid.length = 0;
			} else {
				world.arrSolid = [];
			}
			if (world.arrSolidR is Array) {
				world.arrSolidR.length = 0;
			} else {
				world.arrSolidR = [];
			}
		}
	}
}
